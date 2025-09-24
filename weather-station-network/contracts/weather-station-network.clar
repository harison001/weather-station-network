;; Decentralized Weather Station Network
;; A smart contract for managing a network of weather stations and data collection

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-station-not-found (err u101))
(define-constant err-station-already-exists (err u102))
(define-constant err-invalid-data (err u103))
(define-constant err-station-inactive (err u104))
(define-constant err-insufficient-stake (err u105))
(define-constant err-already-voted (err u106))
(define-constant err-voting-ended (err u107))

;; Minimum stake required to register a weather station (in microSTX)
(define-constant min-stake u1000000)

;; Data structures
(define-map weather-stations
  { station-id: uint }
  {
    owner: principal,
    location: (string-ascii 100),
    latitude: int,
    longitude: int,
    stake: uint,
    is-active: bool,
    reputation: uint,
    data-count: uint,
    last-report: uint
  }
)

(define-map weather-data
  { station-id: uint, timestamp: uint }
  {
    temperature: int,
    humidity: uint,
    pressure: uint,
    wind-speed: uint,
    wind-direction: uint,
    rainfall: uint,
    reporter: principal
  }
)

(define-map station-validations
  { station-id: uint, validator: principal }
  {
    vote: bool,
    timestamp: uint
  }
)

(define-map validation-rounds
  { station-id: uint, round: uint }
  {
    total-votes: uint,
    positive-votes: uint,
    end-block: uint,
    is-active: bool
  }
)

;; Variables
(define-data-var next-station-id uint u1)
(define-data-var next-validation-round uint u1)
(define-data-var total-stations uint u0)
(define-data-var validation-period uint u144) ;; ~24 hours in blocks

;; Private functions
(define-private (is-valid-temperature (temp int))
  (and (>= temp -500) (<= temp 600))
)

(define-private (is-valid-humidity (humidity uint))
  (and (>= humidity u0) (<= humidity u100))
)

(define-private (is-valid-pressure (pressure uint))
  (and (>= pressure u800) (<= pressure u1200))
)

(define-private (is-valid-wind-speed (speed uint))
  (<= speed u300)
)

(define-private (is-valid-wind-direction (direction uint))
  (< direction u360)
)

(define-private (is-valid-rainfall (rainfall uint))
  (<= rainfall u1000)
)

(define-private (calculate-reputation-bonus (station-id uint))
  (let ((station-data (unwrap-panic (map-get? weather-stations {station-id: station-id}))))
    (if (> (get data-count station-data) u100)
      u50
      (/ (get data-count station-data) u2)
    )
  )
)

;; Public functions

;; Register a new weather station
(define-public (register-weather-station 
  (location (string-ascii 100))
  (latitude int)
  (longitude int)
  (stake-amount uint))
  (let ((station-id (var-get next-station-id)))
    (asserts! (>= stake-amount min-stake) err-insufficient-stake)
    (asserts! (is-none (map-get? weather-stations {station-id: station-id})) err-station-already-exists)
    (asserts! (and (>= latitude -900000) (<= latitude 900000)) err-invalid-data)
    (asserts! (and (>= longitude -1800000) (<= longitude 1800000)) err-invalid-data)
    
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set weather-stations
      {station-id: station-id}
      {
        owner: tx-sender,
        location: location,
        latitude: latitude,
        longitude: longitude,
        stake: stake-amount,
        is-active: true,
        reputation: u100,
        data-count: u0,
        last-report: block-height
      }
    )
    
    (var-set next-station-id (+ station-id u1))
    (var-set total-stations (+ (var-get total-stations) u1))
    (ok station-id)
  )
)

;; Submit weather data
(define-public (submit-weather-data
  (station-id uint)
  (temperature int)
  (humidity uint)
  (pressure uint)
  (wind-speed uint)
  (wind-direction uint)
  (rainfall uint))
  (let ((station (unwrap! (map-get? weather-stations {station-id: station-id}) err-station-not-found)))
    (asserts! (is-eq (get owner station) tx-sender) err-owner-only)
    (asserts! (get is-active station) err-station-inactive)
    (asserts! (is-valid-temperature temperature) err-invalid-data)
    (asserts! (is-valid-humidity humidity) err-invalid-data)
    (asserts! (is-valid-pressure pressure) err-invalid-data)
    (asserts! (is-valid-wind-speed wind-speed) err-invalid-data)
    (asserts! (is-valid-wind-direction wind-direction) err-invalid-data)
    (asserts! (is-valid-rainfall rainfall) err-invalid-data)
    
    (map-set weather-data
      {station-id: station-id, timestamp: block-height}
      {
        temperature: temperature,
        humidity: humidity,
        pressure: pressure,
        wind-speed: wind-speed,
        wind-direction: wind-direction,
        rainfall: rainfall,
        reporter: tx-sender
      }
    )
    
    ;; Update station statistics
    (map-set weather-stations
      {station-id: station-id}
      (merge station {
        data-count: (+ (get data-count station) u1),
        last-report: block-height,
        reputation: (+ (get reputation station) (calculate-reputation-bonus station-id))
      })
    )
    
    (ok true)
  )
)

;; Vote on station validation
(define-public (vote-station-validation (station-id uint) (vote bool))
  (let ((station (unwrap! (map-get? weather-stations {station-id: station-id}) err-station-not-found))
        (current-round (var-get next-validation-round)))
    (asserts! (is-none (map-get? station-validations {station-id: station-id, validator: tx-sender})) err-already-voted)
    
    (map-set station-validations
      {station-id: station-id, validator: tx-sender}
      {vote: vote, timestamp: block-height}
    )
    
    (let ((round-data (default-to 
      {total-votes: u0, positive-votes: u0, end-block: (+ block-height (var-get validation-period)), is-active: true}
      (map-get? validation-rounds {station-id: station-id, round: current-round}))))
      
      (map-set validation-rounds
        {station-id: station-id, round: current-round}
        {
          total-votes: (+ (get total-votes round-data) u1),
          positive-votes: (+ (get positive-votes round-data) (if vote u1 u0)),
          end-block: (get end-block round-data),
          is-active: (get is-active round-data)
        }
      )
    )
    
    (ok true)
  )
)

;; Finalize validation round
(define-public (finalize-validation (station-id uint) (round uint))
  (let ((round-data (unwrap! (map-get? validation-rounds {station-id: station-id, round: round}) err-station-not-found))
        (station (unwrap! (map-get? weather-stations {station-id: station-id}) err-station-not-found)))
    (asserts! (>= block-height (get end-block round-data)) err-voting-ended)
    (asserts! (get is-active round-data) err-voting-ended)
    
    (let ((approval-rate (/ (* (get positive-votes round-data) u100) (get total-votes round-data))))
      (if (>= approval-rate u60)
        ;; Station approved - increase reputation
        (map-set weather-stations
          {station-id: station-id}
          (merge station {reputation: (+ (get reputation station) u25)})
        )
        ;; Station rejected - decrease reputation and deactivate if too low
        (let ((new-reputation (if (> (get reputation station) u25) (- (get reputation station) u25) u0)))
          (map-set weather-stations
            {station-id: station-id}
            (merge station {
              reputation: new-reputation,
              is-active: (> new-reputation u20)
            })
          )
        )
      )
    )
    
    ;; Mark round as inactive
    (map-set validation-rounds
      {station-id: station-id, round: round}
      (merge round-data {is-active: false})
    )
    
    (ok true)
  )
)

;; Deactivate a weather station (owner only)
(define-public (deactivate-station (station-id uint))
  (let ((station (unwrap! (map-get? weather-stations {station-id: station-id}) err-station-not-found)))
    (asserts! (is-eq (get owner station) tx-sender) err-owner-only)
    
    (map-set weather-stations
      {station-id: station-id}
      (merge station {is-active: false})
    )
    
    ;; Return stake to owner
    (try! (as-contract (stx-transfer? (get stake station) tx-sender (get owner station))))
    (var-set total-stations (- (var-get total-stations) u1))
    (ok true)
  )
)

;; Read-only functions

;; Get weather station information
(define-read-only (get-weather-station (station-id uint))
  (map-get? weather-stations {station-id: station-id})
)

;; Get weather data
(define-read-only (get-weather-data (station-id uint) (timestamp uint))
  (map-get? weather-data {station-id: station-id, timestamp: timestamp})
)

;; Get total number of active stations
(define-read-only (get-total-stations)
  (var-get total-stations)
)

;; Get next station ID
(define-read-only (get-next-station-id)
  (var-get next-station-id)
)

;; Get validation round info
(define-read-only (get-validation-round (station-id uint) (round uint))
  (map-get? validation-rounds {station-id: station-id, round: round})
)

;; Check if station is active
(define-read-only (is-station-active (station-id uint))
  (match (map-get? weather-stations {station-id: station-id})
    station (get is-active station)
    false
  )
)

;; Get station reputation
(define-read-only (get-station-reputation (station-id uint))
  (match (map-get? weather-stations {station-id: station-id})
    station (get reputation station)
    u0
  )
)

;; Enhanced features for development branch

;; Get weather stations within a radius (simplified version)
(define-read-only (get-stations-in-area (center-lat int) (center-lon int) (radius uint))
  (let ((stations-list (list)))
    ;; This is a simplified version - in reality you'd implement proper distance calculation
    (ok (var-get total-stations))
  )
)

;; Get average temperature from all active stations
(define-read-only (get-network-average-temperature)
  (let ((total-temp 0)
        (active-stations (var-get total-stations)))
    (if (> active-stations u0)
      (ok (/ total-temp active-stations))
      (ok 0)
    )
  )
)

;; Get station performance metrics
(define-read-only (get-station-metrics (station-id uint))
  (match (map-get? weather-stations {station-id: station-id})
    station (ok {
      uptime: (if (> (- block-height (get last-report station)) u1440) u0 u100),
      data-quality: (get reputation station),
      total-reports: (get data-count station)
    })
    (err err-station-not-found)
  )
)

;; Emergency weather alert system
(define-public (submit-emergency-alert (station-id uint) (alert-type (string-ascii 50)) (severity uint))
  (let ((station (unwrap! (map-get? weather-stations {station-id: station-id}) err-station-not-found)))
    (asserts! (is-eq (get owner station) tx-sender) err-owner-only)
    (asserts! (get is-active station) err-station-inactive)
    (asserts! (<= severity u5) err-invalid-data)
    
    ;; In a real implementation, this would trigger network-wide notifications
    (ok true)
  )
)