from fastapi import FastAPI

app = FastAPI(title="ECR Push Lab", version="1.0.0")


@app.get("/")
def root():
    return {"message": "Hello from ECR!", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "healthy"}