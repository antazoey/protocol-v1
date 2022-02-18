# Structs

struct InvestorFunds:
  currentAmountDeposited: uint256
  totalAmountDeposited: uint256
  totalAmountWithdrawn: uint256
  currentPendingRewards: uint256
  totalRewardsAmount: uint256
  activeForRewards: bool

# Events

event Deposit:
    _from: address
    amount: uint256
    erc20TokenContract: address
event Withdrawal:
    _from: address
    amount: uint256
    erc20TokenContract: address
event Compound:
    _from: address
    rewards: uint256
    erc20TokenContract: address
event FundsTransfer:
    _to: address
    amount: uint256
    erc20TokenContract: address
event FundsReceipt:
    _from: address
    amount: uint256
    interestAmount: uint256
    erc20TokenContract: address

# Functions

@external
def changeOwnership(_newOwner: address) -> address:
    pass

@external
def changeMaxCapitalEfficiency(_newMaxCapitalEfficiency: uint256) -> uint256:
    pass

@external
def changePoolStatus(_flag: bool) -> bool:
    pass

@external
def deprecate() -> bool:
    pass

@view
@external
def hasFundsToInvest() -> bool:
    pass

@view
@external
def maxFundsInvestable() -> int256:
    pass

@view
@external
def lastDaysApr(_nLastDays: uint256) -> uint256:
    pass

@view
@external
def depositorsArray() -> DynArray[address, 1125899906842624]:
    pass

@external
def deposit(_amount: uint256) -> InvestorFunds:
    pass

@external
def withdraw(_amount: uint256) -> InvestorFunds:
    pass

@external
def compoundRewards() -> InvestorFunds:
    pass

@external
def sendFunds(_to: address, _amount: uint256) -> uint256:
    pass

@external
def receiveFunds(_owner: address, _amount: uint256, _rewardsAmount: uint256) -> uint256:
    pass

@payable
@external
def __default__():
    pass

@view
@external
def owner() -> address:
    pass

@view
@external
def loansContract() -> address:
    pass

@view
@external
def erc20TokenContract() -> address:
    pass

@view
@external
def maxCapitalEfficienty() -> uint256:
    pass

@view
@external
def isPoolActive() -> bool:
    pass

@view
@external
def isPoolDeprecated() -> bool:
    pass

@view
@external
def isPoolInvesting() -> bool:
    pass

@view
@external
def funds(arg0: address) -> InvestorFunds:
    pass

@view
@external
def depositors(arg0: uint256) -> address:
    pass

@view
@external
def fundsAvailable() -> uint256:
    pass

@view
@external
def fundsInvested() -> uint256:
    pass

@view
@external
def totalFundsInvested() -> uint256:
    pass

@view
@external
def totalRewards() -> uint256:
    pass

@view
@external
def rewardsByDay(arg0: uint256) -> uint256:
    pass

@view
@external
def days(arg0: uint256) -> uint256:
    pass
