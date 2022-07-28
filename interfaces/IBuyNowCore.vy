# Structs

struct Liquidation:
    collateralAddress: address
    tokenId: uint256
    startTime: uint256
    gracePeriodMaturity: uint256
    buyNowPeriodMaturity: uint256
    principal: uint256
    interestAmount: uint256
    apr: uint256 # parts per 10000, e.g. 2.5% is represented by 250 parts per 10000
    gracePeriodPrice: uint256
    buyNowPeriodPrice: uint256
    borrower: address
    erc20TokenContract: address
    inAuction: bool

# Events

event OwnershipTransferred:
    ownerIndexed: address
    proposedOwnerIndexed: address
    owner: address
    proposedOwner: address
event OwnerProposed:
    ownerIndexed: address
    proposedOwnerIndexed: address
    owner: address
    proposedOwner: address
event BuyNowPeripheralAddressSet:
    currentValue: address
    newValue: address
event LoansCoreAddressAdded:
    erc20TokenContractIndexed: address
    currentValue: address
    newValue: address
    erc20TokenContract: address
event LoansCoreAddressRemoved:
    erc20TokenContractIndexed: address
    currentValue: address
    erc20TokenContract: address

# Functions

@view
@external
def getLiquidation(_collateralAddress: address, _tokenId: uint256) -> Liquidation:
    pass

@view
@external
def getLiquidationStartTime(_collateralAddress: address, _tokenId: uint256) -> uint256:
    pass

@view
@external
def getLiquidationGracePeriodMaturity(_collateralAddress: address, _tokenId: uint256) -> uint256:
    pass

@view
@external
def getLiquidationBuyNowPeriodMaturity(_collateralAddress: address, _tokenId: uint256) -> uint256:
    pass

@view
@external
def getLiquidationPrincipal(_collateralAddress: address, _tokenId: uint256) -> uint256:
    pass

@view
@external
def getLiquidationInterestAmount(_collateralAddress: address, _tokenId: uint256) -> uint256:
    pass

@view
@external
def getLiquidationAPR(_collateralAddress: address, _tokenId: uint256) -> uint256:
    pass

@view
@external
def getLiquidationBorrower(_collateralAddress: address, _tokenId: uint256) -> address:
    pass

@view
@external
def getLiquidationERC20Contract(_collateralAddress: address, _tokenId: uint256) -> address:
    pass

@view
@external
def isLiquidationInAuction(_collateralAddress: address, _tokenId: uint256) -> bool:
    pass

@external
def proposeOwner(_address: address):
    pass

@external
def claimOwnership():
    pass

@external
def setBuyNowPeripheralAddress(_address: address):
    pass

@external
def addLoansCoreAddress(_erc20TokenContract: address, _address: address):
    pass

@external
def removeLoansCoreAddress(_erc20TokenContract: address):
    pass

@external
def addLiquidation(_collateralAddress: address, _tokenId: uint256, _startTime: uint256, _gracePeriodMaturity: uint256, _buyNowPeriodMaturity: uint256, _principal: uint256, _interestAmount: uint256, _apr: uint256, _gracePeriodPrice: uint256, _buyNowPeriodPrice: uint256, _borrower: address, _erc20TokenContract: address):
    pass

@external
def removeLiquidation(_collateralAddress: address, _tokenId: uint256):
    pass

@view
@external
def owner() -> address:
    pass

@view
@external
def proposedOwner() -> address:
    pass

@view
@external
def buyNowPeripheralAddress() -> address:
    pass

@view
@external
def loansCoreAddresses(arg0: address) -> address:
    pass


