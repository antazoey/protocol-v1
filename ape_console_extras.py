import os
import web3
from scripts.deployment import DeploymentManager, Environment


ENV = Environment[os.environ.get("ENV", "local")]

def inject_poa(w3):
    w3.middleware_onion.inject(web3.middleware.geth_poa_middleware, layer=0)
    return w3

def transfer(w3, wallet, val=10**60):
    b = w3.eth.coinbase
    w3.eth.send_transaction({"from": b, "to": wallet, "value": val})
    print(f"new balance: {w3.eth.get_balance(wallet)}")

def propose_owner(dm, from_wallet, to_wallet):
    contracts = [c for c in dm.context.contract.values() if hasattr(c.contract, "proposeOwner")]
    for c in contracts:
        c.contract.proposeOwner(to_wallet, sender=from_wallet)

def claim_ownership(dm, wallet):
    contracts = [c for c in dm.context.contract.values() if hasattr(c.contract, "claimOwnership")]
    for c in contracts:
        c.contract.claimOwnership(sender=wallet)

def ape_init_extras(network):
    dm = DeploymentManager(ENV)

    globals()["dm"] = dm
    globals()["owner"] = dm.owner
    for k, v in dm.context.contract.items():
        globals()[k.replace(".", "_").replace("-", "_")] = v.contract
        print(k.replace(".", "_"), v.contract)
    for k, v in dm.context.config.items():
        globals()[k.replace(".", "_").replace("-", "_")] = v
