DROP TABLE IF EXISTS watchlist;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS stocks;

CREATE TABLE users {
    id SERIAL PRIMARY KEY NOT NULL, 
    username VARCHAR(16) NOT NULL,
    password VARCHAR(128) NOT NULL,
    phone_number VARCHAR(10)
}

CREATE TABLE stocks {
    id SERIAL PRIMARY KEY NOT NULL,
    ticker VARCHAR(5) NOT NULL
}

CREATE TABLE watchlist {
    id SERIAL PRIMARY KEY NOT NULL,
    user_id INTEGER REFERENCES users(id) NOT NULL,
    stock_id INTEGER REFERENCES stocks(id) NOT NULL
}

INSERT INTO stocks(ticker) 
VALUES
    ("AAPL"),
    ("NFLX"),
    ("AMZN"),
    ("NVDA"),
    ("META"),
    ("MSFT"),
    ("AMD");