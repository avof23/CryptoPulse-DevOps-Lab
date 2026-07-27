from sqlalchemy.orm import sessionmaker

from app.db import MappingTB, engine
from app.main import cryptapp

CRYPTO_MAPPING = {
    'btc': 'bitcoin',
    'eth': 'ethereum',
    'sol': 'solana',
    'usdt': 'tether',
    'ton': 'the-open-network',
    'trx': 'tron'
}

SessionLocal = sessionmaker(bind=engine)


def seed_cryptos(logger_=None):
    """Function for populating the database from the CRYPTO_MAPPING dictionary"""
    session = SessionLocal()
    try:
        for symbol, coingecko_id in CRYPTO_MAPPING.items():
            existing_crypto = session.query(MappingTB).filter_by(symbol=symbol).first()

            if not existing_crypto:
                new_crypto = MappingTB(symbol=symbol, name=coingecko_id)
                session.add(new_crypto)
                if logger_:
                    logger_.info(f"Crypto added to DB: {symbol} -> {coingecko_id}")
            else:
                existing_crypto.name = coingecko_id
                if logger_:
                    logger_.info(f"Crypto already exists in DB, updated: {symbol}")

        session.commit()
        if logger_:
            logger_.info("Database successful updated list of crypto")

    except Exception as e:
        session.rollback()
        if logger_:
            logger_.error(f"Error seeding database: {e}")
        raise
    finally:
        session.close()


if __name__ == "__main__":
    try:
        logger = cryptapp.logger
    except ImportError:
        logger = None

    seed_cryptos(logger_=logger)
