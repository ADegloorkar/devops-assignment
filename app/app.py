from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return """
    <h1>DevOps Assignment</h1>
    <h2>Docker Deployment Successful!</h2>
    <p>Deployed using Jenkins, Docker and Ansible.</p>
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)