"""
Conexão com o PostgreSQL.

As credenciais chegam por variável de ambiente. Na AWS, DB_PASSWORD é injetada
pelo ECS a partir do Secrets Manager (o secret é gerenciado pelo próprio RDS
via manage_master_user_password), então a senha nunca aparece na task
definition, no state do Terraform nem no código.
"""
import os

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker


def database_url() -> str:
    host = os.environ["DB_HOST"]
    port = os.getenv("DB_PORT", "5432")
    name = os.environ["DB_NAME"]
    user = os.environ["DB_USER"]
    password = os.environ["DB_PASSWORD"]
    return f"postgresql+psycopg://{user}:{password}@{host}:{port}/{name}"


# pool_pre_ping evita a task servir erro depois que o RDS reinicia ou faz
# failover e derruba as conexões ociosas do pool.
engine = create_engine(
    database_url(),
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=5,
    connect_args={"connect_timeout": 5},
)

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_session():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
