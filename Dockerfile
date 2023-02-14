FROM nfcore/base
LABEL authors="Marc Hoeppner" \
      description="Docker image containing all requirements for IKMB Dragen pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/dragen-variant-calling-1.0/bin:$PATH

RUN apt-get -y update && apt-get -y install make wget git g++ ruby-full ruby-dev

RUN gem install json rest-client
