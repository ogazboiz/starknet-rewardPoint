#!/bin/bash

# deploy_with_sncast.sh - Deploy reward points contract using Starknet Foundry

echo "🚀 Deploying Reward Points Contract with Starknet Foundry"
echo "========================================================"

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

# Configuration
CLASS_HASH="0x06c7ba6d4b3e238e6486528e5561caaf38f5e413fa581fa0eca1330f130dc031"
ARGENT_ADDRESS="0x01cDA33A6d3FFB2cb426a29d9C560545469e2daA00F1c58cdC28c59AF90Cd42e"
ACCOUNT_NAME="reward_deployer"

info "Starting deployment process..."

# Step 1: Check if sncast is installed
if ! command -v sncast &> /dev/null; then
    error "Starknet Foundry (sncast) not found!"
    echo "Install with: curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh"
    exit 1
fi

success "Starknet Foundry found: $(sncast --version)"

# Step 2: Setup snfoundry.toml
info "Setting up snfoundry.toml..."
cat > snfoundry.toml << 'EOF'
[sncast.sepolia]
url = "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/uHo7ICSBqpDRguF-DhjWWF72l-sPapYX"
network = "sepolia"
EOF

success "Configuration created"

# Step 3: Check if account exists
info "Checking if account '$ACCOUNT_NAME' exists..."
if sncast --profile sepolia account list | grep -q "$ACCOUNT_NAME"; then
    success "Account '$ACCOUNT_NAME' already exists"
    
    # Check if deployed
    if sncast --profile sepolia account list | grep -A 10 "$ACCOUNT_NAME" | grep -q "deployed: true"; then
        success "Account is already deployed"
        ACCOUNT_EXISTS=true
    else
        warning "Account exists but not deployed"
        ACCOUNT_EXISTS=false
    fi
else
    info "Creating new account '$ACCOUNT_NAME'..."
    
    if sncast --profile sepolia account create --name "$ACCOUNT_NAME"; then
        success "Account created successfully"
        ACCOUNT_EXISTS=false
    else
        error "Failed to create account"
        exit 1
    fi
fi

# Step 4: Show account info and funding instructions
info "Getting account information..."
sncast --profile sepolia account list

ACCOUNT_ADDRESS=$(sncast --profile sepolia account list | grep -A 10 "$ACCOUNT_NAME" | grep "address:" | awk '{print $2}')

if [ -z "$ACCOUNT_ADDRESS" ]; then
    error "Could not get account address"
    exit 1
fi

success "Account address: $ACCOUNT_ADDRESS"

# Step 5: Deploy account if needed
if [ "$ACCOUNT_EXISTS" = false ]; then
    echo ""
    warning "⚠️  IMPORTANT: Fund your account before deploying!"
    echo "1. Go to: https://faucet.starknet.io/"
    echo "2. Enter your address: $ACCOUNT_ADDRESS"
    echo "3. Get test ETH"
    echo ""
    read -p "Press Enter after funding your account..."
    
    info "Deploying account..."
    if sncast --profile sepolia account deploy --name "$ACCOUNT_NAME"; then
        success "Account deployed successfully"
    else
        error "Account deployment failed"
        exit 1
    fi
fi

# Step 6: Deploy the contract
info "Deploying reward points contract..."
echo "Class Hash: $CLASS_HASH"
echo "Owner (Argent): $ARGENT_ADDRESS"

DEPLOY_OUTPUT=$(sncast --profile sepolia --account "$ACCOUNT_NAME" deploy \
    --class-hash "$CLASS_HASH" \
    --constructor-calldata "$ARGENT_ADDRESS" 2>&1)

if [[ $? -eq 0 ]]; then
    CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oE "0x[0-9a-fA-F]{64}" | tail -1)
    
    if [ -n "$CONTRACT_ADDRESS" ]; then
        success "Contract deployed successfully!"
    else
        # Try to extract from different format
        CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Contract address" | grep -oE "0x[0-9a-fA-F]{64}")
        
        if [ -n "$CONTRACT_ADDRESS" ]; then
            success "Contract deployed successfully!"
        else
            error "Could not extract contract address from output:"
            echo "$DEPLOY_OUTPUT"
            exit 1
        fi
    fi
else
    error "Contract deployment failed:"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# Step 7: Verify deployment
info "Verifying deployment..."
sleep 3

OWNER_CHECK=$(sncast --profile sepolia call \
    --contract-address "$CONTRACT_ADDRESS" \
    --function get_owner 2>/dev/null)

if [[ "$OWNER_CHECK" == *"$ARGENT_ADDRESS"* ]]; then
    success "✅ Deployment verified! Owner matches your Argent address"
else
    warning "⚠️  Could not verify owner (this might be normal)"
fi

# Step 8: Save deployment info
cat > deployment_info.json << EOF
{
    "contract_address": "$CONTRACT_ADDRESS",
    "class_hash": "$CLASS_HASH",
    "owner": "$ARGENT_ADDRESS",
    "deployer_account": "$ACCOUNT_ADDRESS",
    "network": "sepolia",
    "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "deployed_with": "starknet_foundry"
}
EOF

success "Deployment info saved to deployment_info.json"

# Final output
cat << EOF

🎉 SUCCESS! Contract Deployed!

📋 CONTRACT DETAILS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Contract Address: $CONTRACT_ADDRESS
✅ Owner (Argent): $ARGENT_ADDRESS
✅ Deployer Account: $ACCOUNT_ADDRESS
✅ Class Hash: $CLASS_HASH
✅ Network: Starknet Sepolia
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔗 View on Starkscan:
https://sepolia.starkscan.co/contract/$CONTRACT_ADDRESS

📋 FOR YOUR DELIVERABLES:
   Deliverable 2: $CONTRACT_ADDRESS

🧪 Test Commands:
# Check owner
sncast --profile sepolia call --contract-address $CONTRACT_ADDRESS --function get_owner

# Add points (as owner - you'll need to use your Argent wallet for this)
# Transfer ownership to the deployer account first, or use a web interface

📄 All details saved to: deployment_info.json

EOF

success "🚀 Deployment complete!"