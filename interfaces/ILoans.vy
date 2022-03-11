# Structs

struct Collateral:
  contract: address
  id: uint256

struct Collaterals:
  size: uint256
  contracts: address[10]
  ids: uint256[10]

struct Loan:
  id: uint256
  amount: uint256
  interest: uint256
  maturity: uint256
  startTime: uint256
  collaterals: Collaterals
  paidAmount: uint256

# Events

event LoanCreated:
    borrower: address
    loanId: uint256
    erc20TokenContract: address
event LoanValidated:
    borrower: address
    loanId: uint256
    erc20TokenContract: address
event LoanInvalidated:
    borrower: address
    loanId: uint256
    erc20TokenContract: address
event LoanPaid:
    borrower: address
    loanId: uint256
    amount: uint256
    erc20TokenContract: address
event LoanDefaulted:
    borrower: address
    loanId: uint256
    amount: uint256
    erc20TokenContract: address
event PendingLoanCanceled:
    borrower: address
    loanId: uint256
    erc20TokenContract: address
event LoanCanceled:
    borrower: address
    loanId: uint256
    erc20TokenContract: address

# Functions

@external
def changeOwnership(_newOwner: address) -> address:
    pass

@external
def changeMaxAllowedLoans(_maxAllowedLoans: uint256) -> uint256:
    pass

@external
def changeMaxAllowedLoanDuration(_maxAllowedLoanDuration: uint256) -> uint256:
    pass

@external
def addCollateralToWhitelist(_address: address) -> bool:
    pass

@external
def removeCollateralFromWhitelist(_address: address) -> bool:
    pass

@external
def changeMinLoanAmount(_newMinLoanAmount: uint256) -> uint256:
    pass

@external
def changeMaxLoanAmount(_newMaxLoanAmount: uint256) -> uint256:
    pass

@external
def setLoansCoreAddress(_address: address) -> address:
    pass

@external
def setLendingPoolAddress(_address: address) -> address:
    pass

@external
def changeContractStatus(_flag: bool) -> bool:
    pass

@external
def deprecate() -> bool:
    pass

@view
@external
def getWhitelistedCollateralsAddresses() -> DynArray[address, 1125899906842624]:
    pass

@view
@external
def erc20TokenSymbol() -> String[10]:
    pass

@view
@external
def getLoanIdsUsedByAddress(_borrower: address) -> bool[10]:
    pass

@view
@external
def getPendingBorrowerLoans(_borrower: address) -> DynArray[Loan, 10]:
    pass

@view
@external
def getPendingBorrowerLoan(_borrower: address, _loanId: uint256) -> Loan:
    pass

@view
@external
def getBorrowerLoans(_borrower: address) -> DynArray[Loan, 10]:
    pass

@view
@external
def getBorrowerLoan(_borrower: address, _loanId: uint256) -> Loan:
    pass

@external
def reserve(_amount: uint256, _interest: uint256, _maturity: uint256, _collaterals: DynArray[Collateral, 10]) -> uint256:
    pass

@external
def validate(_borrower: address, _loanId: uint256):
    pass

@external
def invalidate(_borrower: address, _loanId: uint256):
    pass

@external
def pay(_loanId: uint256, _amountPaid: uint256):
    pass

@external
def settleDefault(_borrower: address, _loanId: uint256):
    pass

@external
def cancelPendingLoan(_loanId: uint256):
    pass

@external
def cancelStartedLoan(_loanId: uint256):
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
def maxAllowedLoans() -> uint256:
    pass

@view
@external
def maxAllowedLoanDuration() -> uint256:
    pass

@view
@external
def bufferToCancelLoan() -> uint256:
    pass

@view
@external
def minLoanAmount() -> uint256:
    pass

@view
@external
def maxLoanAmount() -> uint256:
    pass

@view
@external
def isAcceptingLoans() -> bool:
    pass

@view
@external
def isDeprecated() -> bool:
    pass

@view
@external
def whitelistedCollateralsAddresses(arg0: uint256) -> address:
    pass

@view
@external
def whitelistedCollaterals(arg0: address) -> bool:
    pass

@view
@external
def loansCoreAddress() -> address:
    pass

@view
@external
def lendingPoolAddress() -> address:
    pass

@view
@external
def currentStartedLoans() -> uint256:
    pass

@view
@external
def totalStartedLoans() -> uint256:
    pass

@view
@external
def totalPaidLoans() -> uint256:
    pass

@view
@external
def totalDefaultedLoans() -> uint256:
    pass

@view
@external
def totalDefaultedLoansAmount() -> uint256:
    pass

@view
@external
def totalCanceledLoans() -> uint256:
    pass
