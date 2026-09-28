"""
API REST do Projeto 2 do portfólio DevOps.

Diferença para o Projeto 1: o estado agora vive no PostgreSQL (RDS), não em
memória. É isso que torna a infraestrutura em volta interessante — rede
privada para o banco, senha vinda do Secrets Manager e deploy sem downtime
com o banco continuando de pé.

Endpoints:
  GET    /health      -> liveness: responde sem tocar no banco
  GET    /ready       -> readiness: verifica a conexão com o banco
  GET    /tasks       -> lista tarefas
  POST   /tasks       -> cria tarefa
  GET    /tasks/{id}  -> busca uma tarefa
  DELETE /tasks/{id}  -> remove uma tarefa
"""
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy import String, Boolean, DateTime, select, text
from sqlalchemy.orm import Mapped, Session, mapped_column

from db import Base, engine, get_session

app = FastAPI(title="devops-02-ecs-microservice", version="1.0.0")


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    done: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class TaskIn(BaseModel):
    title: str
    done: bool = False


class TaskOut(TaskIn):
    model_config = ConfigDict(from_attributes=True)

    id: str
    created_at: datetime


@app.on_event("startup")
def create_schema() -> None:
    # Trade-off documentado no README: criação de schema no startup em vez de
    # ferramenta de migração. Suficiente para uma tabela; Alembic entra quando
    # houver evolução de schema para versionar.
    Base.metadata.create_all(engine)


@app.get("/health")
def health() -> dict:
    """Liveness. Não toca no banco de propósito: se o RDS cair, o ALB não deve
    derrubar tasks saudáveis que voltariam sozinhas quando o banco voltar."""
    return {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}


@app.get("/ready")
def ready(session: Session = Depends(get_session)) -> dict:
    """Readiness: confirma que a conexão com o banco está de pé."""
    try:
        session.execute(text("SELECT 1"))
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"banco indisponivel: {exc}")
    return {"status": "ready"}


@app.get("/tasks", response_model=list[TaskOut])
def list_tasks(session: Session = Depends(get_session)) -> list[Task]:
    return list(session.scalars(select(Task).order_by(Task.created_at)))


@app.post("/tasks", response_model=TaskOut, status_code=201)
def create_task(payload: TaskIn, session: Session = Depends(get_session)) -> Task:
    task = Task(
        id=str(uuid4()),
        title=payload.title,
        done=payload.done,
        created_at=datetime.now(timezone.utc),
    )
    session.add(task)
    session.commit()
    return task


@app.get("/tasks/{task_id}", response_model=TaskOut)
def get_task(task_id: str, session: Session = Depends(get_session)) -> Task:
    task = session.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    return task


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: str, session: Session = Depends(get_session)) -> None:
    task = session.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    session.delete(task)
    session.commit()
