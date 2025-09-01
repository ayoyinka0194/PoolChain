 PoolChain

A smart contractpowered carpooling platform that automatically splits costs, handles payments, and rewards ecofriendly shared rides with tokens.

 Overview

PoolChain transforms carpooling through blockchain automation, creating a transparent and rewarding system where users benefit from sharing rides. The platform automatically handles cost calculations, secure payments, and environmental incentives through smart contracts on the Stacks blockchain.

 Features

 🚗 Automated Ride Management
 Smart contractpowered ride creation and management
 Realtime passenger tracking (up to 10 passengers per ride)
 Automatic ride status updates and completion tracking
 Origin and destination management with validation

 💰 Intelligent Cost Splitting
 Automatic costperperson calculations
 Secure STX payments with builtin validation
 Platform fee collection (2.5% default, adjustable)
 Direct driver payments with instant settlement

 🌱 Eco Token Rewards
 Custom eco token system rewarding sustainable transportation
 1% eco reward rate for both drivers and passengers
 Token transfers between users
 Reputation and ecoscore tracking

 👥 User Profile System
 Driver and passenger registration
 Comprehensive user profiles with ride history
 Reputation scoring based on participation
 Ecoscore tracking for environmental impact

 🔒 Security & Validation
 Comprehensive input validation for all user data
 Principal verification and balance checks
 Overflow protection for all arithmetic operations
 Rolebased access control for sensitive functions

 Smart Contract Functions

 User Management
 registeruser: Register as driver or passenger
 getuserprofile: Retrieve user profile information
 getecotokenbalance: Check eco token balance

 Ride Operations
 createride: Create new carpooling rides
 joinride: Join existing rides as passenger
 completeride: Mark rides as completed (driver only)
 getrideinfo: View ride details and status
 getridepayments: Check payment status for rides

 Payment System
 completepayment: Process ride payments with automatic splitting
 transferecotokens: Transfer eco tokens between users
 Automatic platform fee collection and eco reward distribution

 Platform Administration
 setplatformfeerate: Adjust platform fee percentage (owner only)
 setecorewardrate: Modify eco token reward rate (owner only)
 getplatformfeerate: View current platform fee rate

 Getting Started

 Prerequisites
 Clarinet CLI installed
 Stacks wallet for testing and transactions
 Basic understanding of Clarity smart contracts

 Installation
1. Clone the repository
2. Run clarinet check to verify contract syntax
3. Use clarinet console for interactive testing
4. Deploy with clarinet deploy

 Testing
bash
clarinet check
clarinet test


 Usage Example
clarity
 Register as a driver
(contractcall? .poolchain registeruser true)

 Create a ride
(contractcall? .poolchain createride "Downtown" "Airport" u50000000 u4)

 Join a ride as passenger
(contractcall? .poolchain joinride u1)

 Complete payment
(contractcall? .poolchain completepayment u1)


 📄 License

This project is licensed under the MIT License.