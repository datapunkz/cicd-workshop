FROM cimg/python:3.10.0

# Create app directory
WORKDIR /home/circleci/project

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY requirements.txt provision_workshop.py /home/circleci/project/

RUN pip install -r requirements.txt 

CMD [ "python", "scripts/util/provisioning/provision_workshop.py" ]