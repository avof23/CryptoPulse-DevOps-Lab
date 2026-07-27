import os
from pathlib import Path
import logging
from logging.handlers import RotatingFileHandler

import requests
from flask import Flask, render_template, jsonify, request
from sqlalchemy.orm import sessionmaker

from app.db import MappingTB, engine

cryptapp = Flask(__name__)

HOME_PROJECT = Path(__file__).resolve().parent.parent
logdir = os.path.join(HOME_PROJECT, 'logs')
log_file_path = os.path.join(logdir, 'cryptapp.log')

if not os.path.exists(logdir):
    os.mkdir(logdir)

file_handler = RotatingFileHandler(
    log_file_path,
    maxBytes=1_048_576,
    backupCount=10,
    encoding='utf-8'
)

file_handler.setLevel(logging.INFO)
formatter = logging.Formatter(
    '[%(asctime)s] %(levelname)s in %(module)s: %(message)s'
)
file_handler.setFormatter(formatter)
cryptapp.logger.addHandler(file_handler)
cryptapp.logger.setLevel(logging.INFO)
cryptapp.logger.info('Application running')

SessionLocal = sessionmaker(bind=engine)


def get_name_by_symbol(symbol: str) -> str | None:
    """Get crypto name from database by (symbol)"""
    session = SessionLocal()
    try:
        crypto = session.query(MappingTB).filter_by(symbol=symbol.lower()).first()
        return crypto.name if crypto else None
    finally:
        session.close()


def get_all_cryptos() -> dict:
    """Return all crypto from database in dict {symbol: name}"""
    session = SessionLocal()
    try:
        cryptos = session.query(MappingTB).all()
        return {item.symbol: item.name for item in cryptos}
    finally:
        session.close()


@cryptapp.route("/")
def index():
    # Get Bicoin price from public API
    try:
        response = requests.get(
            "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"
        )
        price = response.json()["bitcoin"]["usd"]
    except Exception as e:
        price = f"Error on receive data: {e}"
        cryptapp.logger.error(price)

    return render_template("index.html", price=price)


@cryptapp.route('/api/price', methods=['GET'])
def get_crypto_price():
    symbol = request.args.get('symbol', '').lower()

    if not symbol:
        return jsonify({'error': 'The “symbol” parameter is not specified'}), 400

    crypto_id = get_name_by_symbol(symbol)
    if not crypto_id:
        return jsonify({
            'error': f'Unknown crypto: {symbol}',
            'available': list(get_all_cryptos().keys())
        }), 404

    url = f"https://api.coingecko.com/api/v3/simple/price?ids={crypto_id}&vs_currencies=usd"

    try:
        response = requests.get(url, timeout=5)
        data = response.json()

        if crypto_id in data:
            price = data[crypto_id]['usd']
            cryptapp.logger.info(f"Request for {symbol.upper()}: ${price}")

            return jsonify({
                'symbol': symbol.upper(),
                'price_usd': price
            })
        else:
            return jsonify({'error': 'Unable to retrieve data from the external API'}), 500

    except requests.RequestException as e:
        cryptapp.logger.error(f"Error connection with crypto API: {e}")
        return jsonify({'error': 'Internal server error'}), 500


if __name__ == "__main__":
    cryptapp.run(host="0.0.0.0", port=5000)
