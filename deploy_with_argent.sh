#!/bin/bash

# deploy_with_argent.sh - Deploy contract using Argent wallet

echo "🦾 Deploying Reward Points Contract with Argent Wallet"
echo "======================================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }


# Make executable


# Run with your Argent address

# Configuration
RPC_URL="https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/uHo7ICSBqpDRguF-DhjWWF72l-sPapYX"

# Check if user provided Argent address
if [ -z "$1" ]; then
    echo ""
    echo "Usage: $0 <ARGENT_ADDRESS>"
    echo ""
    echo "Example: $0 0x123abc...your_argent_address"
    echo ""
    echo "📱 To get your Argent address:"
    echo "1. Open Argent wallet app"
    echo "2. Go to Settings → Account"
    echo "3. Copy your account address"
    exit 1
fi

ARGENT_ADDRESS="$1"
info "Using Argent address: $ARGENT_ADDRESS"

# Check if Starkli is installed
if ! command -v starkli &> /dev/null; then
    error "Starkli not found. Installing..."
    curl https://get.starkli.sh | sh
    starkliup
    export PATH="$HOME/.starkli/bin:$PATH"
fi

# Check if contract is built
if [ ! -f "target/dev/reward_points_contract_RewardPointsContract.contract_class.json" ]; then
    info "Building contract..."
    if ! scarb build; then
        error "Failed to build contract"
        exit 1
    fi
    success "Contract built successfully"
fi

# Setup account profile
info "Setting up Argent account profile..."
mkdir -p ~/.starkli-wallets/argent

# Fetch account info
if starkli account fetch "$ARGENT_ADDRESS" \
    --rpc "$RPC_URL" \
    --output ~/.starkli-wallets/argent/account.json 2>/dev/null; then
    
    success "Account info fetched successfully"
    
    echo ""
    warning "For deployment, you need to import your Argent private key to Starkli"
    echo ""
    echo "📱 To export your private key from Argent:"
    echo "1. Open Argent wallet"
    echo "2. Go to Settings → Security → Export Private Key"
    echo "3. Enter your password"
    echo "4. Copy the private key"
    echo ""
    
    read -p "Do you have your Argent private key ready? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Creating keystore from your private key..."
        echo "⚠️  You'll be prompted to enter your private key and set a password"
        
        if starkli signer keystore from-key ~/.starkli-wallets/argent/keystore.json; then
            success "Keystore created successfully"
        else
            error "Failed to create keystore"
            exit 1
        fi
    else
        error "Private key is required for deployment. Exiting..."
        exit 1
    fi
else
    error "Could not fetch account info for $ARGENT_ADDRESS"
    exit 1
fi

# Declare contract
info "Declaring contract..."
DECLARE_OUTPUT=$(starkli declare \
    target/dev/reward_points_contract_RewardPointsContract.contract_class.json \
    --keystore ~/.starkli-wallets/argent/keystore.json \
    --account ~/.starkli-wallets/argent/account.json \
    --rpc "$RPC_URL" \
    --watch 2>&1)

if [[ $? -eq 0 ]]; then
    CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -oE "0x[0-9a-fA-F]{64}" | tail -1)
    success "Contract declared: $CLASS_HASH"
elif echo "$DECLARE_OUTPUT" | grep -q "is already declared"; then
    CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -oE "0x[0-9a-fA-F]{64}" | head -1)
    warning "Contract already declared: $CLASS_HASH"
else
    error "Declaration failed:"
    echo "$DECLARE_OUTPUT"
    exit 1
fi

# Deploy contract
info "Deploying contract..."
DEPLOY_OUTPUT=$(starkli deploy "$CLASS_HASH" \
    --keystore ~/.starkli-wallets/argent/keystore.json \
    --account ~/.starkli-wallets/argent/account.json \
    --rpc "$RPC_URL" \
    --watch \
    "$ARGENT_ADDRESS" 2>&1)

if [[ $? -eq 0 ]]; then
    CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oE "0x[0-9a-fA-F]{64}" | tail -1)
    success "Contract deployed: $CONTRACT_ADDRESS"
else
    error "Deployment failed:"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# Save deployment info
cat > deployment.json << EOF
{
    "contract_address": "$CONTRACT_ADDRESS",
    "class_hash": "$CLASS_HASH", 
    "owner": "$ARGENT_ADDRESS",
    "network": "sepolia",
    "deployed_with": "argent_wallet"
}
EOF

success "Deployment info saved to deployment.json"

cat << EOF

🎉 Deployment Complete!

📋 Your Contract Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Contract Address: $CONTRACT_ADDRESS
Owner (Your Argent): $ARGENT_ADDRESS
Class Hash: $CLASS_HASH
Network: Starknet Sepolia
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔗 View on Starkscan:
https://sepolia.starkscan.co/contract/$CONTRACT_ADDRESS

📄 For your deliverables:
   Deliverable 2: $CONTRACT_ADDRESS

EOF

success "🦾 Your contract is now live on Starknet Sepolia!"