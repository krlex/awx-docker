FROM centos:7

RUN yum -y update
RUN yum -y install vim policycoreutils-python
CMD semanage port -a -t http_port_t -p tcp 8050
CMD semanage port -a -t http_port_t -p tcp 8051
CMD semanage port -a -t http_port_t -p tcp 8052

CMD systemctl stop firewalld
CMD systemctl disable firewalld

RUN yum -y install epel-release
RUN yum -y install centos-release-scl centos-release-scl-rh wget

CMD wget -O /etc/yum.repos.d/ansible-awx.repo https://copr.fedorainfracloud.org/coprs/mrmeee/ansible-awx/repo/epel-7/mrmeee-ansible-awx-epel-7.repo

CMD echo "[bintraybintray-rabbitmq-rpm] \
        name=bintray-rabbitmq-rpm \
        baseurl=https://dl.bintray.com/rabbitmq/rpm/rabbitmq-server/v3.7.x/el/7/ \
        gpgcheck=0 \
        repo_gpgcheck=0 \
        enabled=1" > /etc/yum.repos.d/rabbitmq.repo

CMD echo "[bintraybintray-rabbitmq-erlang-rpm] \
        name=bintray-rabbitmq-erlang-rpm \
        baseurl=https://dl.bintray.com/rabbitmq-erlang/rpm/erlang/21/el/7/ \
        gpgcheck=0 \
        repo_gpgcheck=0 \
        enabled=1" > /etc/yum.repos.d/rabbitmq-erlang.repo

RUN yum -y install rabbitmq-server rh-git29 rh-postgresql10 memcached nginx ansible-awx
RUN yum -y install rh-python36
RUN yum -y install --disablerepo='*' --enablerepo='copr:copr.fedorainfracloud.org:mrmeee:ansible-awx, base' -x *-debuginfo rh-python36*

CMD cp -rf /etc/tower/settings.py /etc/tower/settings.py.bak
CMD scl enable rh-postgresql10 "postgresql-setup initdb"

CMD systemctl start rh-postgresql10-postgresql.service
CMD systemctl start rabbitmq-server

CMD scl enable rh-postgresql10 "su postgres -c \"createuser -S awx\""
CMD scl enable rh-postgresql10 "su postgres -c \"createdb -O awx awx\""

CMD sudo -u awx scl enable rh-python36 rh-postgresql10 rh-git29 "GIT_PYTHON_REFRESH=quiet awx-manage migrate"

CMD echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'root@localhost', 'password')" | sudo -u awx scl enable rh-python36 rh-postgresql10 "GIT_PYTHON_REFRESH=quiet awx-manage shell"
CMD sudo -u awx scl enable rh-python36 rh-postgresql10 rh-git29 "GIT_PYTHON_REFRESH=quiet awx-manage create_preload_data" # Optional Sample Configuration
CMD sudo -u awx scl enable rh-python36 rh-postgresql10 rh-git29 "GIT_PYTHON_REFRESH=quiet awx-manage provision_instance --hostname=$(hostname)"
CMD sudo -u awx scl enable rh-python36 rh-postgresql10 rh-git29 "GIT_PYTHON_REFRESH=quiet awx-manage register_queue --queuename=tower --hostnames=$(hostname)"

CMD sed -i -e "s|'NAME': 'awx'|'NAME': '$DB_NAME'|" /etc/tower/settings.py
CMD sed -i -e 's|os.getenv("DATABASE_USER", None)|os.getenv("DATABASE_USER", "'$DB_USER'")|' /etc/tower/settings.py
CMD sed -i -e 's|os.getenv("DATABASE_PASSWORD", None)|os.getenv("DATABASE_PASSWORD", "'$DB_PASSWORD'")|' /etc/tower/settings.py
CMD sed -i -e 's|os.getenv("DATABASE_HOST", None)|os.getenv("DATABASE_HOST", "'$DB_HOST'")|' /etc/tower/settings.py
CMD sed -i -e 's|os.getenv("DATABASE_PORT", None)|os.getenv("DATABASE_PORT", "'$DB_PORT'")|' /etc/tower/settings.py
CMD sed -i -e "s|# 'USER':|'USER':|" /etc/tower/settings.py
CMD sed -i -e "s|# 'PASSWORD':|'PASSWORD':|" /etc/tower/settings.py
CMD sed -i -e "s|# 'HOST':|'HOST':|" /etc/tower/settings.py
CMD sed -i -e "s|# 'PORT':|'PORT':|" /etc/tower/settings.py

CMD wget -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/MrMEEE/awx-build/master/nginx.conf
CMD systemctl start awx
CMD systemctl start nginx

CMD systemctl enable awx
CMD systemctl enable nginx

