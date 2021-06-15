#python3

import json
import os
import random
import time
from datetime import datetime, timedelta

import requests
from web3 import Web3



PROVIDER = "http://127.0.0.1:8545"
PEPE_ABI = json.load(open(os.path.abspath(f"{os.path.dirname(os.path.abspath(__file__))}/assets/PepeToken.abi")))

# PancakPair_ABI = json.load(
    # open(os.path.abspath(f"{os.path.dirname(os.path.abspath(__file__))}/assets/" + "pancakepair.abi")))

conn = Web3(Web3.HTTPProvider(PROVIDER, request_kwargs={"timeout": 60}))
address = "0xFE31B29Db1f3D04Dea4F5430302C8D17b973c320"
private_key = "0xfc87f123834ae64aa8d53f6007f7bd1fde780a09c77b45fa49c630073a86cf31"
gasPrice = conn.toWei(5, "gwei")

pepe_adress = Web3.toChecksumAddress('0xf13593546Be957f4917A2B68dF1D794c585CDc91')



def _create_transaction_params(value=0, gas=1650000):
    return {
        "from": address,
        "value": value,
        'gasPrice': gasPrice,
        "gas": gas,
        "nonce": conn.eth.getTransactionCount(address),
    }


def _send_transaction(func, params):
    tx = func.buildTransaction(params)
    signed_tx = conn.eth.account.sign_transaction(tx, private_key=private_key)
    return conn.eth.sendRawTransaction(signed_tx.rawTransaction)



# def pancake_v2_client():
#     return PancakeV2Client(address, private_key, provider=PROVIDER)


def start():
    print("start!")
    print("*"*50)
    print("*"*50)
    print("*"*50)

    PEPE_Contract = conn.eth.contract(address=pepe_adress, abi=PEPE_ABI)
    print(PEPE_Contract.functions.symbol().call())
    

start()