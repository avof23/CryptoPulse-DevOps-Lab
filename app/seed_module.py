from app.db import Mapping_tb, engine
from sqlalchemy.orm import sessionmaker

CRYPTO_MAPPING = {
    'btc': 'bitcoin',
    'eth': 'ethereum',
    'sol': 'solana',
    'usdt': 'tether',
    'ton': 'the-open-network',
    'trx': 'tron'
}

SessionLocal = sessionmaker(bind=engine)


def seed_cryptos(logger=None):
    """Function for populating the database from the CRYPTO_MAPPING dictionary"""
    session = SessionLocal()
    try:
        for symbol, coingecko_id in CRYPTO_MAPPING.items():
            existing_crypto = session.query(Mapping_tb).filter_by(symbol=symbol).first()

            if not existing_crypto:
                new_crypto = Mapping_tb(symbol=symbol, name=coingecko_id)
                session.add(new_crypto)
                if logger:
                    logger.info(f"Crypto added to DB: {symbol} -> {coingecko_id}")
            else:
                existing_crypto.name = coingecko_id
                if logger:
                    logger.info(f"Crypto already exists in DB, updated: {symbol}")

        session.commit()
        if logger:
            logger.info("Database successful updated list of crypto")

    except Exception as e:
        session.rollback()
        if logger:
            logger.error(f"Error seeding database: {e}")
        raise
    finally:
        session.close()


if __name__ == "__main__":
    try:
        from app.main import cryptapp
        logger = cryptapp.logger
    except ImportError:
        logger = None

    seed_cryptos(logger=logger)
