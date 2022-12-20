#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# System Required: CentOS 7+/Ubuntu 18+/Debian 10+
# Version: v1.3.4
# Description: One click Install Trojan Panel server
# Author: jonssonyan <https://jonssonyan.com>
# Github: https://github.com/trojanpanel/install-script

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  get_arch=""
  can_google=0

  # Docker
  DOCKER_MIRROR='"https://registry.docker-cn.com","https://hub-mirror.c.163.com","https://docker.mirrors.ustc.edu.cn"'

  # 项目目录
  TP_DATA="/tpdata/"

  STATIC_HTML="https://github.com/trojanpanel/install-script/releases/download/v1.0.0/html.tar.gz"

  # Caddy
  CADDY_DATA="/tpdata/caddy/"
  CADDY_Config="/tpdata/caddy/config.json"
  CADDY_SRV="/tpdata/caddy/srv/"
  CADDY_CERT="/tpdata/caddy/cert/"
  CADDY_LOG="/tpdata/caddy/log/"
  DOMAIN_FILE="/tpdata/caddy/domain.lock"
  CADDY_CERT_DIR="/tpdata/caddy/cert/certificates/acme-v02.api.letsencrypt.org-directory/"
  domain=""
  caddy_remote_port=8863
  your_email=""
  ssl_option=1
  ssl_module_type=1
  ssl_module="acme"
  crt_path=""
  key_path=""

  # MariaDB
  MARIA_DATA="/tpdata/mariadb/"
  mariadb_ip="::1"
  mariadb_port=9507
  mariadb_user="root"
  mariadb_pas=""

  #Redis
  REDIS_DATA="/tpdata/redis/"
  redis_host="::1"
  redis_port=6378
  redis_pass=""

  # Trojan Panel
  TROJAN_PANEL_DATA="/tpdata/trojan-panel/"
  TROJAN_PANEL_WEBFILE="/tpdata/trojan-panel/webfile/"
  TROJAN_PANEL_LOGS="/tpdata/trojan-panel/logs/"

  # Trojan Panel UI
  TROJAN_PANEL_UI_DATA="/tpdata/trojan-panel-ui/"
  # Nginx
  NGINX_DATA="/tpdata/nginx/"
  NGINX_CONFIG="/tpdata/nginx/default.conf"
  trojan_panel_ui_port=8888
  https_enable=1

  # Trojan Panel Core
  TROJAN_PANEL_CORE_DATA="/tpdata/trojan-panel-core/"
  TROJAN_PANEL_CORE_LOGS="/tpdata/trojan-panel-core/logs/"
  database="trojan_panel_db"
  account_table="account"

  # Update
  trojan_panel_current_version=""
  trojan_panel_latest_version="1.3.1"
  trojan_panel_core_current_version=""
  trojan_panel_core_latest_version="1.3.1"
  tp_sql_131_132="alter table trojan_panel_db.node_hysteria modify up_mbps int(10) default 100 not null comment '单客户端最大上传速度 单位:Mbps';alter table trojan_panel_db.node_hysteria modify down_mbps int(10) default 100 not null comment '单客户端最大下载速度 单位:Mbps';"
}

echo_content() {
  case $1 in
  "red")
    ${ECHO_TYPE} "\033[31m$2\033[0m"
    ;;
  "green")
    ${ECHO_TYPE} "\033[32m$2\033[0m"
    ;;
  "yellow")
    ${ECHO_TYPE} "\033[33m$2\033[0m"
    ;;
  "blue")
    ${ECHO_TYPE} "\033[34m$2\033[0m"
    ;;
  "purple")
    ${ECHO_TYPE} "\033[35m$2\033[0m"
    ;;
  "skyBlue")
    ${ECHO_TYPE} "\033[36m$2\033[0m"
    ;;
  "white")
    ${ECHO_TYPE} "\033[37m$2\033[0m"
    ;;
  esac
}

mkdir_tools() {
  # 项目目录
  mkdir -p ${TP_DATA}

  # Caddy
  mkdir -p ${CADDY_DATA}
  touch ${CADDY_Config}
  mkdir -p ${CADDY_SRV}
  mkdir -p ${CADDY_CERT}
  mkdir -p ${CADDY_LOG}

  # MariaDB
  mkdir -p ${MARIA_DATA}

  # Redis
  mkdir -p ${REDIS_DATA}

  # Trojan Panel
  mkdir -p ${TROJAN_PANEL_DATA}
  mkdir -p ${TROJAN_PANEL_LOGS}

  # Trojan Panel UI
  mkdir -p ${TROJAN_PANEL_UI_DATA}
  # # Nginx
  mkdir -p ${NGINX_DATA}
  touch ${NGINX_CONFIG}

  # Trojan Panel Core
  mkdir -p ${TROJAN_PANEL_CORE_DATA}
  mkdir -p ${TROJAN_PANEL_CORE_LOGS}
}

can_connect() {
  ping -c2 -i0.3 -W1 "$1" &>/dev/null
  if [[ "$?" == "0" ]]; then
    return 0
  else
    return 1
  fi
}

check_sys() {
  if [[ $(command -v yum) ]]; then
    package_manager='yum'
  elif [[ $(command -v dnf) ]]; then
    package_manager='dnf'
  elif [[ $(command -v apt) ]]; then
    package_manager='apt'
  elif [[ $(command -v apt-get) ]]; then
    package_manager='apt-get'
  fi

  if [[ -z "${package_manager}" ]]; then
    echo_content red "暂不支持该系统"
    exit 0
  fi

  if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
    release="centos"
  elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
    release="debian"
  elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
    release="ubuntu"
  fi

  if [[ -z "${release}" ]]; then
    echo_content red "仅支持CentOS 7+/Ubuntu 18+/Debian 10+系统"
    exit 0
  fi

  if [[ $(arch) =~ ("x86_64"|"amd64"|"arm64"|"aarch64"|"arm"|"s390x") ]]; then
    get_arch=$(arch)
  fi

  if [[ -z "${get_arch}" ]]; then
    echo_content red "仅支持amd64/arm64/arm/s390x处理器架构"
    exit 0
  fi
}

depend_install() {
  if [[ "${package_manager}" != 'yum' && "${package_manager}" != 'dnf' ]]; then
    ${package_manager} update -y
  fi
  ${package_manager} install -y \
    curl \
    wget \
    tar \
    lsof \
    systemd
}

# 安装Docker
install_docker() {
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content green "---> 安装Docker"

    # 关闭防火墙
    if [[ "$(firewall-cmd --state 2>/dev/null)" == "running" ]]; then
      systemctl stop firewalld.service && systemctl disable firewalld.service
    fi

    # 时区
    timedatectl set-timezone Asia/Shanghai

    can_connect www.google.com
    [[ "$?" == "0" ]] && can_google=1

    if [[ ${can_google} == 0 ]]; then
      sh <(curl -sL https://get.docker.com) --mirror Aliyun
      # 设置Docker国内源
      mkdir -p /etc/docker &&
        cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors":[${DOCKER_MIRROR}],
  "log-driver":"json-file",
  "log-opts":{
      "max-size":"50m",
      "max-file":"3"
  }
}
EOF
    else
      sh <(curl -sL https://get.docker.com)
    fi

    systemctl enable docker &&
      systemctl restart docker

    if [[ $(docker -v 2>/dev/null) ]]; then
      echo_content skyBlue "---> Docker安装完成"
    else
      echo_content red "---> Docker安装失败"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Docker"
  fi
}

# 安装Caddy TLS
install_caddy_tls() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> 安装Caddy TLS"

    wget --no-check-certificate -O ${CADDY_DATA}html.tar.gz ${STATIC_HTML} &&
      tar -zxvf ${CADDY_DATA}html.tar.gz -C ${CADDY_SRV}

    read -r -p "请输入Caddy的转发端口(默认:8863): " caddy_remote_port
    [[ -z "${caddy_remote_port}" ]] && caddy_remote_port=8863

    echo_content yellow "提示：请确认域名已经解析到本机 否则可能安装失败"
    while read -r -p "请输入你的域名(必填): " domain; do
      if [[ -z "${domain}" ]]; then
        echo_content red "域名不能为空"
      else
        break
      fi
    done

    read -r -p "请输入你的邮箱(可选): " your_email

    while read -r -p "请选择设置证书的方式?(1/自动申请和续签证书 2/手动设置证书路径 默认:1/自动申请和续签证书): " ssl_option; do
      if [[ -z ${ssl_option} || ${ssl_option} == 1 ]]; then
        while read -r -p "请选择申请证书的方式(1/acme 2/zerossl 默认:1/acme): " ssl_module_type; do
          if [[ -z "${ssl_module_type}" || ${ssl_module_type} == 1 ]]; then
            ssl_module="acme"
            CADDY_CERT_DIR="/tpdata/caddy/cert/certificates/acme-v02.api.letsencrypt.org-directory/"
            break
          elif [[ ${ssl_module_type} == 2 ]]; then
            ssl_module="zerossl"
            CADDY_CERT_DIR="/tpdata/caddy/cert/certificates/acme.zerossl.com-v2-dv90/"
            break
          else
            echo_content red "不可以输入除1和2之外的其他字符"
          fi
        done

        cat >${CADDY_Config} <<EOF
{
    "admin":{
        "disabled":true
    },
    "logging":{
        "logs":{
            "default":{
                "writer":{
                    "output":"file",
                    "filename":"/tpdata/caddy/log/error.log"
                },
                "level":"ERROR"
            }
        }
    },
    "storage":{
        "module":"file_system",
        "root":"${CADDY_CERT}"
    },
    "apps":{
        "http":{
            "servers":{
                "srv0":{
                    "listen":[
                        ":80"
                    ],
                    "routes":[
                        {
                            "match":[
                                {
                                    "host":[
                                        "${domain}"
                                    ]
                                }
                            ],
                            "handle":[
                                {
                                    "handler":"static_response",
                                    "headers":{
                                        "Location":[
                                            "https://{http.request.host}:${caddy_remote_port}{http.request.uri}"
                                        ]
                                    },
                                    "status_code":301
                                }
                            ]
                        }
                    ]
                },
                "srv1":{
                    "listen":[
                        ":${caddy_remote_port}"
                    ],
                    "routes":[
                        {
                            "handle":[
                                {
                                    "handler":"subroute",
                                    "routes":[
                                        {
                                            "match":[
                                                {
                                                    "host":[
                                                        "${domain}"
                                                    ]
                                                }
                                            ],
                                            "handle":[
                                                {
                                                    "handler":"file_server",
                                                    "root":"${CADDY_SRV}",
                                                    "index_names":[
                                                        "index.html",
                                                        "index.htm"
                                                    ]
                                                }
                                            ],
                                            "terminal":true
                                        }
                                    ]
                                }
                            ]
                        }
                    ],
                    "tls_connection_policies":[
                        {
                            "match":{
                                "sni":[
                                    "${domain}"
                                ]
                            }
                        }
                    ],
                    "automatic_https":{
                        "disable":true
                    }
                }
            }
        },
        "tls":{
            "certificates":{
                "automate":[
                    "${domain}"
                ]
            },
            "automation":{
                "policies":[
                    {
                        "issuers":[
                            {
                                "module":"${ssl_module}",
                                "email":"${your_email}"
                            }
                        ]
                    }
                ]
            }
        }
    }
}
EOF
        break
      elif [[ ${ssl_option} == 2 ]]; then
        while read -r -p "请输入证书的.crt文件路径(必填): " crt_path; do
          if [[ -z "${crt_path}" ]]; then
            echo_content red "路径不能为空"
          else
            if [[ ! -f "${crt_path}" ]]; then
              echo_content red "证书的.crt文件路径不存在"
            else
              cp "${crt_path}" "${CADDY_CERT}${domain}.crt"
              break
            fi
          fi
        done

        while read -r -p "请输入证书的.key文件路径(必填): " key_path; do
          if [[ -z "${key_path}" ]]; then
            echo_content red "路径不能为空"
          else
            if [[ ! -f "${key_path}" ]]; then
              echo_content red "证书的.key文件路径不存在"
            else
              cp "${key_path}" "${CADDY_CERT}${domain}.key"
              break
            fi
          fi
        done

        cat >${CADDY_Config} <<EOF
{
    "admin":{
        "disabled":true
    },
    "logging":{
        "logs":{
            "default":{
                "writer":{
                    "output":"file",
                    "filename":"/tpdata/caddy/log/error.log"
                },
                "level":"ERROR"
            }
        }
    },
    "storage":{
        "module":"file_system",
        "root":"${CADDY_CERT}"
    },
    "apps":{
        "http":{
            "servers":{
                "srv0":{
                    "listen":[
                        ":80"
                    ],
                    "routes":[
                        {
                            "match":[
                                {
                                    "host":[
                                        "${domain}"
                                    ]
                                }
                            ],
                            "handle":[
                                {
                                    "handler":"static_response",
                                    "headers":{
                                        "Location":[
                                            "https://{http.request.host}:${caddy_remote_port}{http.request.uri}"
                                        ]
                                    },
                                    "status_code":301
                                }
                            ]
                        }
                    ]
                },
                "srv1":{
                    "listen":[
                        ":${caddy_remote_port}"
                    ],
                    "routes":[
                        {
                            "handle":[
                                {
                                    "handler":"subroute",
                                    "routes":[
                                        {
                                            "match":[
                                                {
                                                    "host":[
                                                        "${domain}"
                                                    ]
                                                }
                                            ],
                                            "handle":[
                                                {
                                                    "handler":"file_server",
                                                    "root":"${CADDY_SRV}",
                                                    "index_names":[
                                                        "index.html",
                                                        "index.htm"
                                                    ]
                                                }
                                            ],
                                            "terminal":true
                                        }
                                    ]
                                }
                            ]
                        }
                    ],
                    "tls_connection_policies":[
                        {
                            "match":{
                                "sni":[
                                    "${domain}"
                                ]
                            }
                        }
                    ],
                    "automatic_https":{
                        "disable":true
                    }
                }
            }
        },
        "tls":{
            "certificates":{
                "automate":[
                    "${domain}"
                ],
                "load_files":[
                    {
                        "certificate":"${CADDY_CERT_DIR}${domain}/${domain}.crt",
                        "key":"${CADDY_CERT_DIR}${domain}/${domain}.key"
                    }
                ]
            },
            "automation":{
                "policies":[
                    {
                        "issuers":[
                            {
                                "module":"${ssl_module}",
                                "email":"${your_email}"
                            }
                        ]
                    }
                ]
            }
        }
    }
}
EOF
        break
      else
        echo_content red "不可以输入除1和2之外的其他字符"
      fi
    done

    if [[ -n $(lsof -i:80,443 -t) ]]; then
      kill -9 "$(lsof -i:80,443 -t)"
    fi

    docker pull caddy:2.6.2 &&
      docker run -d --name trojan-panel-caddy --restart always \
        --network=host \
        -v "${CADDY_Config}":"${CADDY_Config}" \
        -v ${CADDY_CERT}:"${CADDY_CERT_DIR}${domain}/" \
        -v ${CADDY_SRV}:${CADDY_SRV} \
        -v ${CADDY_LOG}:${CADDY_LOG} \
        caddy:2.6.2 caddy run --config ${CADDY_Config}

    if [[ -n $(docker ps -q -f "name=^trojan-panel-caddy$" -f "status=running") ]]; then
      cat >${DOMAIN_FILE} <<EOF
${domain}
EOF
      echo_content skyBlue "---> Caddy安装完成"
    else
      echo_content red "---> Caddy安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    domain=$(cat "${DOMAIN_FILE}")
    echo_content skyBlue "---> 你已经安装了Caddy"
  fi
}

# 安装MariaDB
install_mariadb() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-mariadb$") ]]; then
    echo_content green "---> 安装MariaDB"

    read -r -p "请输入数据库的端口(默认:9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "请输入数据库的用户名(默认:root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "请输入数据库的密码(必填): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    if [[ "${mariadb_user}" == "root" ]]; then
      docker pull mariadb:10.7.3 &&
        docker run -d --name trojan-panel-mariadb --restart always \
          --network=host \
          -e MYSQL_DATABASE="trojan_panel_db" \
          -e MYSQL_ROOT_PASSWORD="${mariadb_pas}" \
          -e TZ=Asia/Shanghai \
          mariadb:10.7.3 \
          --port ${mariadb_port}
    else
      docker pull mariadb:10.7.3 &&
        docker run -d --name trojan-panel-mariadb --restart always \
          --network=host \
          -e MYSQL_DATABASE="trojan_panel_db" \
          -e MYSQL_ROOT_PASSWORD="${mariadb_pas}" \
          -e MYSQL_USER="${mariadb_user}" \
          -e MYSQL_PASSWORD="${mariadb_pas}" \
          -e TZ=Asia/Shanghai \
          mariadb:10.7.3 \
          --port ${mariadb_port}
    fi

    if [[ -n $(docker ps -q -f "name=^trojan-panel-mariadb$" -f "status=running") ]]; then
      echo_content skyBlue "---> MariaDB安装完成"
      echo_content yellow "---> MariaDB root的数据库密码(请妥善保存): ${mariadb_pas}"
      if [[ "${mariadb_user}" != "root" ]]; then
        echo_content yellow "---> MariaDB ${mariadb_user}的数据库密码(请妥善保存): ${mariadb_pas}"
      fi
    else
      echo_content red "---> MariaDB安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了MariaDB"
  fi
}

# 安装Redis
install_redis() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content green "---> 安装Redis"

    read -r -p "请输入Redis的端口(默认:6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "请输入Redis的密码(必填): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    docker pull redis:6.2.7 &&
      docker run -d --name trojan-panel-redis --restart always \
        --network=host \
        redis:6.2.7 \
        redis-server --requirepass "${redis_pass}" --port ${redis_port}

    if [[ -n $(docker ps -q -f "name=^trojan-panel-redis$" -f "status=running") ]]; then
      echo_content skyBlue "---> Redis安装完成"
      echo_content yellow "---> Redis的数据库密码(请妥善保存): ${redis_pass}"
    else
      echo_content red "---> Redis安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Redis"
  fi
}

# 安装TrojanPanel
install_trojan_panel() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel$") ]]; then
    echo_content green "---> 安装Trojan Panel"

    read -r -p "请输入数据库的IP地址(默认:本机数据库): " mariadb_ip
    [[ -z "${mariadb_ip}" ]] && mariadb_ip="::1"
    read -r -p "请输入数据库的端口(默认:9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "请输入数据库的用户名(默认:root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "请输入数据库的密码(必填): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "create database if not exists trojan_panel_db;" &>/dev/null

    read -r -p "请输入Redis的IP地址(默认:本机Redis): " redis_host
    [[ -z "${redis_host}" ]] && redis_host="::1"
    read -r -p "请输入Redis的端口(默认:6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "请输入Redis的密码(必填): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p ${redis_port} -a "${redis_pass}" -e "flushall" &>/dev/null

    docker pull jonssonyan/trojan-panel &&
      docker run -d --name trojan-panel --restart always \
        --network=host \
        -v ${CADDY_SRV}:${TROJAN_PANEL_WEBFILE} \
        -v ${TROJAN_PANEL_LOGS}:${TROJAN_PANEL_LOGS} \
        -v /etc/localtime:/etc/localtime \
        -e "mariadb_ip=${mariadb_ip}" \
        -e "mariadb_port=${mariadb_port}" \
        -e "mariadb_user=${mariadb_user}" \
        -e "mariadb_pas=${mariadb_pas}" \
        -e "redis_host=${redis_host}" \
        -e "redis_port=${redis_port}" \
        -e "redis_pass=${redis_pass}" \
        jonssonyan/trojan-panel

    if [[ -n $(docker ps -q -f "name=^trojan-panel$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel后端安装完成"
    else
      echo_content red "---> Trojan Panel后端安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Trojan Panel后端"
  fi

  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-ui$") ]]; then
    read -r -p "请输入Trojan Panel前端端口(默认:8888): " trojan_panel_ui_port
    [[ -z "${trojan_panel_ui_port}" ]] && trojan_panel_ui_port="8888"

    while read -r -p "请选择Trojan Panel前端是否开启https?(0/关闭 1/开启 默认:1/开启): " https_enable; do
      if [[ -z ${https_enable} || ${https_enable} == 1 ]]; then
        # 配置Nginx
        cat >${NGINX_CONFIG} <<-EOF
server {
    listen       ${trojan_panel_ui_port} ssl;
    server_name  ${domain};

    #强制ssl
    ssl on;
    ssl_certificate      ${CADDY_CERT}${domain}.crt;
    ssl_certificate_key  ${CADDY_CERT}${domain}.key;
    #缓存有效期
    ssl_session_timeout  5m;
    #安全链接可选的加密协议
    ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
    #加密算法
    ssl_ciphers  ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    #使用服务器端的首选算法
    ssl_prefer_server_ciphers  on;

    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        root   ${TROJAN_PANEL_UI_DATA};
        index  index.html index.htm;
    }

    location /api {
        proxy_pass http://[::1]:8081;
    }

    #error_page  404              /404.html;
    #497 http->https
    error_page  497              https://\$host:${trojan_panel_ui_port}\$uri?\$args;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
        break
      else
        if [[ ${https_enable} != 0 ]]; then
          echo_content red "不可以输入除0和1之外的其他字符"
        else
          cat >${NGINX_CONFIG} <<-EOF
server {
    listen       ${trojan_panel_ui_port};
    server_name  localhost;

    location / {
        root   ${TROJAN_PANEL_UI_DATA};
        index  index.html index.htm;
    }

    location /api {
        proxy_pass http://[::1]:8081;
    }

    error_page  497              http://\$host:${trojan_panel_ui_port}\$uri?\$args;

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
          break
        fi
      fi
    done

    docker pull jonssonyan/trojan-panel-ui &&
      docker run -d --name trojan-panel-ui --restart always \
        --network=host \
        -v "${NGINX_CONFIG}":"/etc/nginx/conf.d/default.conf" \
        -v ${CADDY_CERT}:${CADDY_CERT} \
        jonssonyan/trojan-panel-ui

    if [[ -n $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel前端安装完成"
    else
      echo_content red "---> Trojan Panel前端安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Trojan Panel前端"
  fi

  https_flag=$([[ -z ${https_enable} || ${https_enable} == 1 ]] && echo "https" || echo "http")

  echo_content red "\n=============================================================="
  echo_content skyBlue "Trojan Panel 安装成功"
  echo_content yellow "MariaDB ${mariadb_user}的密码(请妥善保存): ${mariadb_pas}"
  echo_content yellow "Redis的密码(请妥善保存): ${redis_pass}"
  echo_content yellow "管理面板地址: ${https_flag}://${domain}:${trojan_panel_ui_port}"
  echo_content yellow "系统管理员 默认用户名: sysadmin 默认密码: 123456 请及时登陆管理面板修改密码"
  echo_content yellow "Trojan Panel私钥和证书目录: ${CADDY_CERT}"
  echo_content red "\n=============================================================="
}

# 安装Trojan Panel Core
install_trojan_panel_core() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-core$") ]]; then
    echo_content green "---> 安装Trojan Panel Core"

    read -r -p "请输入数据库的IP地址(默认:本机数据库): " mariadb_ip
    [[ -z "${mariadb_ip}" ]] && mariadb_ip="::1"
    read -r -p "请输入数据库的端口(默认:9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "请输入数据库的用户名(默认:root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "请输入数据库的密码(必填): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done
    read -r -p "请输入数据库名称(默认:trojan_panel_db): " database
    [[ -z "${database}" ]] && database="trojan_panel_db"
    read -r -p "请输入数据库的用户表名称(默认:account): " account_table
    [[ -z "${account_table}" ]] && account_table="account"

    read -r -p "请输入Redis的IP地址(默认:本机Redis): " redis_host
    [[ -z "${redis_host}" ]] && redis_host="::1"
    read -r -p "请输入Redis的端口(默认:6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "请输入Redis的密码(必填): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    domain=$(cat "${DOMAIN_FILE}")

    docker pull jonssonyan/trojan-panel-core &&
      docker run -d --name trojan-panel-core --restart always \
        --network=host \
        -v ${TROJAN_PANEL_CORE_DATA}bin/xray/config:${TROJAN_PANEL_CORE_DATA}bin/xray/config \
        -v ${TROJAN_PANEL_CORE_DATA}bin/trojango/config:${TROJAN_PANEL_CORE_DATA}bin/trojango/config \
        -v ${TROJAN_PANEL_CORE_DATA}bin/hysteria/config:${TROJAN_PANEL_CORE_DATA}bin/hysteria/config \
        -v ${TROJAN_PANEL_CORE_DATA}bin/naiveproxy/config:${TROJAN_PANEL_CORE_DATA}bin/naiveproxy/config \
        -v ${TROJAN_PANEL_CORE_LOGS}:${TROJAN_PANEL_CORE_LOGS} \
        -v ${CADDY_CERT}:${CADDY_CERT} \
        -v ${CADDY_SRV}:${CADDY_SRV} \
        -v /etc/localtime:/etc/localtime \
        -e "mariadb_ip=${mariadb_ip}" \
        -e "mariadb_port=${mariadb_port}" \
        -e "mariadb_user=${mariadb_user}" \
        -e "mariadb_pas=${mariadb_pas}" \
        -e "database=${database}" \
        -e "account-table=${account_table}" \
        -e "redis_host=${redis_host}" \
        -e "redis_port=${redis_port}" \
        -e "redis_pass=${redis_pass}" \
        -e "crt_path=${CADDY_CERT}${domain}.crt" \
        -e "key_path=${CADDY_CERT}${domain}.key" \
        jonssonyan/trojan-panel-core
    if [[ -n $(docker ps -q -f "name=^trojan-panel-core$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel Core安装完成"
    else
      echo_content red "---> Trojan Panel Core后端安装失败或运行异常,请尝试修复或卸载重装"
      exit 0
    fi
  else
    echo_content skyBlue "---> 你已经安装了Trojan Panel Core"
  fi
}

# 更新Trojan Panel数据结构
update__trojan_panel_database() {
  echo_content skyBlue "---> 更新Trojan Panel数据结构"

  if [[ "${trojan_panel_current_version}" == "1.3.1" ]]; then
    docker exec trojan-panel-mariadb mysql -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "${tp_sql_131_132}" &>/dev/null &&
      trojan_panel_current_version="1.3.2"
  fi

  echo_content skyBlue "---> Trojan Panel数据结构更新完成"
}

# 更新Trojan Panel Core数据结构
update__trojan_panel_core_database() {
  echo_content skyBlue "---> 更新Trojan Panel Core数据结构"

  echo_content skyBlue "---> Trojan Panel Core数据结构更新完成"
}

# 更新Trojan Panel
update_trojan_panel() {
  # 判断Trojan Panel是否安装
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel$") ]]; then
    echo_content red "---> 请先安装Trojan Panel"
    exit 0
  fi

  trojan_panel_current_version=$(docker exec trojan-panel ./trojan-panel -version)
  if [[ -z "${trojan_panel_current_version}" || ! "${trojan_panel_current_version}" =~ ^v.* ]]; then
    echo_content red "---> 当前版本不支持自动化更新"
    exit 0
  fi

  if [[ "${trojan_panel_current_version}" != "${trojan_panel_latest_version}" ]]; then
    echo_content green "---> 更新Trojan Panel"

    read -r -p "请输入数据库的IP地址(默认:本机数据库): " mariadb_ip
    [[ -z "${mariadb_ip}" ]] && mariadb_ip="::1"
    read -r -p "请输入数据库的端口(默认:9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "请输入数据库的用户名(默认:root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "请输入数据库的密码(必填): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    update__trojan_panel_database

    read -r -p "请输入Redis的IP地址(默认:本机Redis): " redis_host
    [[ -z "${redis_host}" ]] && redis_host="::1"
    read -r -p "请输入Redis的端口(默认:6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "请输入Redis的密码(必填): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p ${redis_port} -a "${redis_pass}" -e "flushall" &>/dev/null

    docker rm -f trojan-panel &&
      docker rmi -f jonssonyan/trojan-panel &&
      rm -rf ${TROJAN_PANEL_DATA}

    docker pull jonssonyan/trojan-panel &&
      docker run -d --name trojan-panel --restart always \
        --network=host \
        -v ${CADDY_SRV}:${TROJAN_PANEL_WEBFILE} \
        -v ${TROJAN_PANEL_LOGS}:${TROJAN_PANEL_LOGS} \
        -v /etc/localtime:/etc/localtime \
        -e "mariadb_ip=${mariadb_ip}" \
        -e "mariadb_port=${mariadb_port}" \
        -e "mariadb_user=${mariadb_user}" \
        -e "mariadb_pas=${mariadb_pas}" \
        -e "redis_host=${redis_host}" \
        -e "redis_port=${redis_port}" \
        -e "redis_pass=${redis_pass}" \
        jonssonyan/trojan-panel

    if [[ -n $(docker ps -q -f "name=^trojan-panel$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel后端更新完成"
    else
      echo_content red "---> Trojan Panel后端更新失败或运行异常,请尝试修复或卸载重装"
    fi

    docker rm -f trojan-panel-ui &&
      docker rmi -f jonssonyan/trojan-panel-ui &&
      rm -rf ${TROJAN_PANEL_UI_DATA}

    docker pull jonssonyan/trojan-panel-ui &&
      docker run -d --name trojan-panel-ui --restart always \
        --network=host \
        -v "${NGINX_CONFIG}":"/etc/nginx/conf.d/default.conf" \
        -v ${CADDY_CERT}:${CADDY_CERT} \
        jonssonyan/trojan-panel-ui

    if [[ -n $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel前端更新完成"
    else
      echo_content red "---> Trojan Panel前端更新失败或运行异常,请尝试修复或卸载重装"
    fi
  else
    echo_content skyBlue "---> 你安装的Trojan Panel已经是最新版"
  fi
}

# 更新Trojan Panel Core
update_trojan_panel_core() {
  # 判断Trojan Panel Core是否安装
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-core$") ]]; then
    echo_content red "---> 请先安装Trojan Panel Core"
    exit 0
  fi

  trojan_panel_core_current_version=$(docker exec trojan-panel-core ./trojan-panel-core -version)
  if [[ -z "${trojan_panel_core_current_version}" || ! "${trojan_panel_core_current_version}" =~ ^v.* ]]; then
    echo_content red "---> 当前版本不支持自动化更新"
    exit 0
  fi

  if [[ "${trojan_panel_core_current_version}" != "${trojan_panel_core_latest_version}" ]]; then
    echo_content green "---> 更新Trojan Panel Core"

    read -r -p "请输入数据库的IP地址(默认:本机数据库): " mariadb_ip
    [[ -z "${mariadb_ip}" ]] && mariadb_ip="::1"
    read -r -p "请输入数据库的端口(默认:9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "请输入数据库的用户名(默认:root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "请输入数据库的密码(必填): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done
    read -r -p "请输入数据库名称(默认:trojan_panel_db): " database
    [[ -z "${database}" ]] && database="trojan_panel_db"
    read -r -p "请输入数据库的用户表名称(默认:account): " account_table
    [[ -z "${account_table}" ]] && account_table="account"

    update__trojan_panel_core_database

    read -r -p "请输入Redis的IP地址(默认:本机Redis): " redis_host
    [[ -z "${redis_host}" ]] && redis_host="::1"
    read -r -p "请输入Redis的端口(默认:6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "请输入Redis的密码(必填): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "密码不能为空"
      else
        break
      fi
    done

    docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p ${redis_port} -a "${redis_pass}" -e "flushall" &>/dev/null

    docker rm -f trojan-panel-core &&
      docker rmi -f jonssonyan/trojan-panel-core &&
      rm -rf ${TROJAN_PANEL_CORE_DATA}

    docker pull jonssonyan/trojan-panel-core &&
      docker run -d --name trojan-panel-core --restart always \
        --network=host \
        -v ${TROJAN_PANEL_CORE_DATA}bin:${TROJAN_PANEL_CORE_DATA}bin \
        -v ${TROJAN_PANEL_CORE_LOGS}:${TROJAN_PANEL_CORE_LOGS} \
        -v ${CADDY_CERT}:${CADDY_CERT} \
        -v /etc/localtime:/etc/localtime \
        -e "mariadb_ip=${mariadb_ip}" \
        -e "mariadb_port=${mariadb_port}" \
        -e "mariadb_user=${mariadb_user}" \
        -e "mariadb_pas=${mariadb_pas}" \
        -e "database=${database}" \
        -e "account-table=${account_table}" \
        -e "redis_host=${redis_host}" \
        -e "redis_port=${redis_port}" \
        -e "redis_pass=${redis_pass}" \
        -e "crt_path=${CADDY_CERT}${domain}.crt" \
        -e "key_path=${CADDY_CERT}${domain}.key" \
        jonssonyan/trojan-panel-core

    if [[ -n $(docker ps -q -f "name=^trojan-panel-core$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel Core更新完成"
    else
      echo_content red "---> Trojan Panel Core更新失败或运行异常,请尝试修复或卸载重装"
    fi
  else
    echo_content skyBlue "---> 你安装的Trojan Panel Core已经是最新版"
  fi
}

# 卸载Caddy TLS
uninstall_caddy_tls() {
  # 判断Caddy TLS是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> 卸载Caddy TLS"

    docker rm -f trojan-panel-caddy &&
      rm -rf ${CADDY_DATA}

    echo_content skyBlue "---> Caddy TLS卸载完成"
  else
    echo_content red "---> 请先安装Caddy TLS"
  fi
}

# 卸载MariaDB
uninstall_mariadb() {
  # 判断MariaDB是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-mariadb$") ]]; then
    echo_content green "---> 卸载MariaDB"

    docker rm -f trojan-panel-mariadb &&
      rm -rf ${MARIA_DATA}

    echo_content skyBlue "---> MariaDB卸载完成"
  else
    echo_content red "---> 请先安装MariaDB"
  fi
}

# 卸载Redis
uninstall_redis() {
  # 判断Redis是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content green "---> 卸载Redis"

    docker rm -f trojan-panel-redis &&
      rm -rf ${REDIS_DATA}

    echo_content skyBlue "---> Redis卸载完成"
  else
    echo_content red "---> 请先安装Redis"
  fi
}

# 卸载Trojan Panel
uninstall_trojan_panel() {
  # 判断Trojan Panel是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel$") ]]; then
    echo_content green "---> 卸载Trojan Panel"

    docker rm -f trojan-panel &&
      docker rmi -f jonssonyan/trojan-panel &&
      rm -rf ${TROJAN_PANEL_DATA}

    docker rm -f trojan-panel-ui &&
      docker rmi -f jonssonyan/trojan-panel-ui &&
      rm -rf ${TROJAN_PANEL_UI_DATA} &&
      rm -rf ${NGINX_DATA}

    echo_content skyBlue "---> Trojan Panel卸载完成"
  else
    echo_content red "---> 请先安装Trojan Panel"
  fi
}

# 卸载Trojan Panel Core
uninstall_trojan_panel_core() {
  # 判断Trojan Panel Core是否安装
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-core$") ]]; then
    echo_content green "---> 卸载Trojan Panel Core"

    docker rm -f trojan-panel-core &&
      docker rmi -f jonssonyan/trojan-panel-core &&
      rm -rf ${TROJAN_PANEL_CORE_DATA}

    echo_content skyBlue "---> Trojan Panel Core卸载完成"
  else
    echo_content red "---> 请先安装Trojan Panel Core"
  fi
}

# 卸载全部Trojan Panel相关的容器
uninstall_all() {
  echo_content green "---> 卸载全部Trojan Panel相关的容器"

  docker rm -f $(docker ps -a -q -f "name=^trojan-panel")
  docker rmi -f $(docker images | grep "^jonssonyan/trojan-panel" | awk '{print $3}')
  rm -rf ${TP_DATA}

  echo_content skyBlue "---> 卸载全部Trojan Panel相关的容器完成"
}

# 修改Trojan Panel前端端口
update_trojan_panel_ui_port() {
  if [[ -n $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
    echo_content green "---> 修改Trojan Panel前端端口"

    trojan_panel_ui_port=$(grep 'listen.*ssl' ${NGINX_CONFIG} | awk '{print $2}')
    echo_content yellow "提示：Trojan Panel前端当前端口为 ${trojan_panel_ui_port}"

    read -r -p "请输入Trojan Panel前端新端口(默认:8888): " trojan_panel_ui_port
    [[ -z "${trojan_panel_ui_port}" ]] && trojan_panel_ui_port="8888"
    sed -i "s/listen.*ssl;/listen       ${trojan_panel_ui_port} ssl;/g" ${NGINX_CONFIG} &&
      sed -i "s/https:\/\/\$host:.*\$uri?\$args/https:\/\/\$host:${trojan_panel_ui_port}\$uri?\$args/g" ${NGINX_CONFIG} &&
      docker restart trojan-panel-ui

    if [[ "$?" == "0" ]]; then
      echo_content skyBlue "---> Trojan Panel前端端口修改完成"
    else
      echo_content red "---> Trojan Panel前端端口修改失败"
    fi
  else
    echo_content red "---> Trojan Panel前端未安装或运行异常,请修复或卸载重装后重试"
  fi
}

# 刷新Redis缓存
redis_flush_all() {
  # 判断Redis是否安装
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content red "---> 请先安装Redis"
    exit 0
  fi

  if [[ -z $(docker ps -q -f "name=^trojan-panel-redis$" -f "status=running") ]]; then
    echo_content red "---> Redis运行异常"
    exit 0
  fi

  echo_content green "---> 刷新Redis缓存"

  read -r -p "请输入Redis的IP地址(默认:本机Redis): " redis_host
  [[ -z "${redis_host}" ]] && redis_host="::1"
  read -r -p "请输入Redis的端口(默认:6378): " redis_port
  [[ -z "${redis_port}" ]] && redis_port=6378
  while read -r -p "请输入Redis的密码(必填): " redis_pass; do
    if [[ -z "${redis_pass}" ]]; then
      echo_content red "密码不能为空"
    else
      break
    fi
  done

  docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p ${redis_port} -a "${redis_pass}" -e "flushall" &>/dev/null

  echo_content skyBlue "---> Redis缓存刷新完成"
}

# 故障检测
failure_testing() {
  echo_content green "---> 故障检测开始"
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content red "---> Docker运行异常"
  else
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
      if [[ -z $(docker ps -q -f "name=^trojan-panel-caddy$" -f "status=running") ]]; then
        echo_content red "---> Caddy TLS运行异常 错误日志如下："
        docker logs trojan-panel-caddy
      fi
      domain=$(cat "${DOMAIN_FILE}")
      if [[ -z $(cat "${DOMAIN_FILE}") || ! -d "${CADDY_CERT}" || ! -f "${CADDY_CERT}${domain}.crt" ]]; then
        echo_content red "---> 证书申请异常，请尝试重启服务器将重新申请证书或者重新搭建选择自定义证书选项 错误日志如下："
        tail -n 20 ${CADDY_LOG}error.log
      fi
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-mariadb$") && -z $(docker ps -q -f "name=^trojan-panel-mariadb$" -f "status=running") ]]; then
      echo_content red "---> MariaDB运行异常 错误日志如下："
      docker logs trojan-panel-mariadb
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-redis$") && -z $(docker ps -q -f "name=^trojan-panel-redis$" -f "status=running") ]]; then
      echo_content red "---> Redis运行异常 错误日志如下："
      docker logs trojan-panel-redis
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel$") && -z $(docker ps -q -f "name=^trojan-panel$" -f "status=running") ]]; then
      echo_content red "---> Trojan Panel后端运行异常 错误日志如下："
      tail -n 20 ${TROJAN_PANEL_LOGS}trojan-panel.log
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-ui$") && -z $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
      echo_content red "---> Trojan Panel前端运行异常 错误日志如下："
      docker logs trojan-panel-ui
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-core$") && -z $(docker ps -q -f "name=^trojan-panel-core$" -f "status=running") ]]; then
      echo_content red "---> Trojan Panel Core运行异常 错误日志如下："
      tail -n 20 ${TROJAN_PANEL_CORE_LOGS}trojan-panel.log
    fi
  fi
  echo_content green "---> 故障检测结束"
}

log_query() {
  while :; do
    echo_content skyBlue "可以查询日志的应用如下:"
    echo_content yellow "1. Trojan Panel"
    echo_content yellow "2. Trojan Panel Core"
    echo_content yellow "3. 退出"
    read -r -p "请选择应用(默认:1): " select_log_query_type
    [[ -z "${select_log_query_type}" ]] && select_log_query_type=1

    case ${select_log_query_type} in
    1)
      log_file_path=${TROJAN_PANEL_LOGS}trojan-panel.log
      ;;
    2)
      log_file_path=${TROJAN_PANEL_CORE_LOGS}trojan-panel-core.log
      ;;
    3)
      break
      ;;
    *)
      echo_content red "没有这个选项"
      continue
      ;;
    esac

    read -r -p "请输入查询的行数(默认:20): " select_log_query_line_type
    [[ -z "${select_log_query_line_type}" ]] && select_log_query_line_type=20

    if [[ -f ${log_file_path} ]]; then
      echo_content skyBlue "日志文件如下:"
      tail -n ${select_log_query_line_type} ${log_file_path}
    else
      echo_content red "不存在日志文件"
    fi
  done
}

main() {
  cd "$HOME" || exit 0
  init_var
  mkdir_tools
  check_sys
  depend_install
  clear
  echo_content red "\n=============================================================="
  echo_content skyBlue "System Required: CentOS 7+/Ubuntu 18+/Debian 10+"
  echo_content skyBlue "Version: v1.3.4"
  echo_content skyBlue "Description: One click Install Trojan Panel server"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/trojanpanel"
  echo_content skyBlue "Docs: https://trojanpanel.github.io"
  echo_content red "\n=============================================================="
  echo_content yellow "1. 安装Trojan Panel"
  echo_content yellow "2. 安装Trojan Panel Core"
  echo_content yellow "3. 安装Caddy TLS"
  echo_content yellow "4. 安装MariaDB"
  echo_content yellow "5. 安装Redis"
  echo_content green "\n=============================================================="
  echo_content yellow "6. 更新Trojan Panel"
  echo_content yellow "7. 安装Trojan Panel Core"
  echo_content green "\n=============================================================="
  echo_content yellow "8. 卸载Trojan Panel"
  echo_content yellow "9. 卸载Trojan Panel Core"
  echo_content yellow "10. 卸载Caddy TLS"
  echo_content yellow "11. 卸载MariaDB"
  echo_content yellow "12. 卸载Redis"
  echo_content yellow "13. 卸载全部Trojan Panel相关的应用"
  echo_content green "\n=============================================================="
  echo_content yellow "14. 修改Trojan Panel前端端口"
  echo_content yellow "15. 刷新Redis缓存"
  echo_content green "\n=============================================================="
  echo_content yellow "16. 故障检测"
  echo_content yellow "17. 日志查询"
  read -r -p "请选择:" selectInstall_type
  case ${selectInstall_type} in
  1)
    install_docker
    install_caddy_tls
    install_mariadb
    install_redis
    install_trojan_panel
    ;;
  2)
    install_docker
    install_caddy_tls
    install_trojan_panel_core
    ;;
  3)
    install_docker
    install_caddy_tls
    ;;
  4)
    install_docker
    install_mariadb
    ;;
  5)
    install_docker
    install_redis
    ;;
  6)
    update_trojan_panel
    ;;
  7)
    update_trojan_panel_core
    ;;
  8)
    uninstall_trojan_panel
    ;;
  9)
    uninstall_trojan_panel_core
    ;;
  10)
    uninstall_caddy_tls
    ;;
  11)
    uninstall_mariadb
    ;;
  12)
    uninstall_redis
    ;;
  13)
    uninstall_all
    ;;
  14)
    update_trojan_panel_ui_port
    ;;
  15)
    redis_flush_all
    ;;
  16)
    failure_testing
    ;;
  17)
    log_query
    ;;
  *)
    echo_content red "没有这个选项"
    ;;
  esac
}

main