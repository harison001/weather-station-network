# Decentralized Weather Station Network

A blockchain-based weather station network built on the Stacks blockchain using Clarity smart contracts.

## Features

- **Station Registration**: Weather stations can register with a stake
- **Data Submission**: Stations submit weather data with validation
- **Reputation System**: Stations earn reputation based on data quality
- **Validation Network**: Peer validation of station data
- **Stake Management**: Economic incentives for honest behavior

## Smart Contract Functions

### Public Functions

- `register-weather-station`: Register a new weather station
- `submit-weather-data`: Submit weather measurements
- `vote-station-validation`: Vote on station validation
- `finalize-validation`: Complete validation rounds
- `deactivate-station`: Deactivate a weather station

### Read-Only Functions

- `get-weather-station`: Get station information
- `get-weather-data`: Retrieve weather data
- `get-total-stations`: Get total active stations
- `is-station-active`: Check station status
- `get-station-reputation`: Get station reputation

## Data Structure

Weather data includes:
- Temperature (°C * 10)
- Humidity (%)
- Pressure (hPa)
- Wind speed (km/h)
- Wind direction (degrees)
- Rainfall (mm)

## Usage

1. Deploy the contract to Stacks blockchain
2. Register weather stations with minimum stake
3. Submit weather data regularly
4. Participate in validation to earn rewards
5. Monitor station reputation and status

## Development

```bash
# Test the contract
clarinet test

# Check syntax
clarinet check

# Start local development
clarinet console

## Enhanced Features (Development Branch)

### New Functions Added:
- `get-stations-in-area`: Find weather stations within a geographic radius
- `get-network-average-temperature`: Calculate network-wide temperature average
- `get-station-metrics`: Get performance metrics for individual stations
- `submit-emergency-alert`: Submit emergency weather alerts

### Performance Improvements:
- Enhanced data validation
- Improved reputation calculation
- Better error handling
- Network-wide analytics

### Future Enhancements:
- Real-time data streaming
- Machine learning integration
- Mobile app API
- Weather prediction algorithms