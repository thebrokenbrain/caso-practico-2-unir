# Descripción
Repositorio anexo a la resolución de la actividad del caso práctico 2 correspondiente al "Programa Avanzado en Cloud
Computing. Arquitecturas y Soluciones" impartido por la UNIR.

Este repositorio contiene las plantillas de CloudFormation y operaciones necesarias para desplegar una infraestructura
en AWS que permite la instalación del CMS Drupal en un entorno de alta disponibilidad y escalabilidad.

# Diagrama de la infraestructura
![Diagrama de la infraestructura](./images/diagram.png)

# Requisitos
- [Python 3.12](https://www.python.org/downloads/)
- [pip](https://pip.pypa.io/en/stable/installation/)
- [Pipenv](https://pypi.org/project/pipenv/)
- [make](https://www.gnu.org/software/make/)
- [aws-cli (versión 2)](https://docs.aws.amazon.com/es_es/cli/latest/userguide/getting-started-install.html)
- Idealmente un sistema Linux o macOS, aunque también es posible seguir los pasos en Windows 10/11 con WSL2.

# Instalación

## 1. Clonar el repositorio

```bash
git clone git@github.com:thebrokenbrain/caso-practico-2.git
```

## 2. Verificar requisitos e instalar dependencias

Acceder al directorio del repositorio y ejecutar el siguiente comando para verificar que se cumplen los requisitos:

```bash
make prepare
```

Si se cumplen todos los requisitos se instalarán automaticamente las dependencias del proyecto (`pipenv install`).

## 3. Activar el entorno virtual

```bash
pipenv shell
```

## 4. Desplegar la infraestructura en AWS

Para desplegar la infraestructura en AWS con los parámetros por defecto, ejecutar el siguiente comando:

```bash
make deploy-infra
```

La operación `deploy-infra` realizará las siguientes acciones de forma automática:

- Validar la sintaxis de las plantillas de CloudFormation mediante `cfn-lint`.
- Crear un archivo `.env` con las variables de entorno necesarias para el despliegue, estas son:
  - `AWS_BUCKET_NAME`. Nombre aleatorio con el que se creará el bucket de S3.
  - `AWS_KEY_PAIR_NAME`. Nombre aleatorio con el que se creará el par de claves.
  - `AWS_RDS_DB_PASSWORD`. Contraseña aleatoria para la base de datos RDS.
  - `AWS_STACK_NAME`. Nombre aleatorio con el que se creará el stack principal de CloudFormation.
- Crear un par de claves en AWS con el nombre `mykeypair-AWS_KEY_PAIR_NAME` y almacenar la clave privada en
el directorio actual.
- Crear un bucket de S3 en AWS con el nombre `bucket-s3-AWS_BUCKET_NAME`.
- Subir los archivos de las plantillas de CloudFormation al bucket de S3.
- Crear un stack de CloudFormation en AWS con el nombre `stack-AWS_STACK_NAME` en donde se desplegará toda
la infraestructura definida en las plantillas con unos parámetros por defecto.

Los parámetros por defecto con los que se realiza el despliegue son los siguientes:

```bash
@aws cloudformation deploy \
  --stack-name=XXXX \
  --template-file=aws_cfn_templates/aws-cfn-main-template.yaml \
  --parameter-overrides \
      BastionEc2InstanceType=t2.micro \
      BucketName=XXXX \
      DesiredCapacity=2 \
      DbInstanceType=db.t3.small \
      DbUsername=admin \
      DbUserPassword=XXXX \
      DrupalImage="josemi/drupal-ecs-boilerplate:latest" \
      KeyPairName=XXXX \
      MaxCpuAndMemory=1vCpu-2GB \
      PublicSubnet1Cidr=10.0.10.0/24 \
      PrivateSubnet1Cidr=10.0.11.0/24 \
      PublicSubnet2Cidr=10.0.20.0/24 \
      PrivateSubnet2Cidr=10.0.21.0/24 \
      ProjectName=myweb \
      TaskRole=LabRole \
      VpcCidr=10.0.0.0/16 \
  --capabilities \
      CAPABILITY_IAM \
      CAPABILITY_NAMED_IAM
```

Si todo ha ido bien, accediendo a la URL del DNS público del balanceador de carga se podrá ver la pantalla de
instalación de Drupal.

# Eliminar la infraestructura en AWS

Cuando se desee eliminar la infraestructura creada en AWS, ejecutar el siguiente comando:

```bash
make destroy-infra
```

La operación `destroy-infra` realizará las siguientes acciones de forma automática:

- Eliminar el contenido del bucket de S3 creado para almacenar las plantillas.
- Eliminar el bucket de S3 `bucket-s3-AWS_BUCKET_NAME`.
- Eliminar el par de claves privada `mykeypair-AWS_KEY_PAIR_NAME` y el fichero `.pem` asociado que se encuentra
en el directorio actual.
- Eliminar la infraestructura creada en AWS mediante el stack `stack-AWS_STACK_NAME`.
- Eliminar el archivo `.env` con las variables de entorno creadas en el paso de despliegue.

# Listado de operaciones disponibles en el fichero Makefile

| Operación        | Descripción                                              |
|------------------|----------------------------------------------------------|
| prepare          | Verificar requisitos e instalar dependencias             |
| deploy-infra     | Desplegar la infraestructura en AWS                      |
| destroy-infra    | Eliminar la infraestructura en AWS                       |
| create-bucket    | Crear un bucket de S3 en AWS                             |
| delete-bucket    | Eliminar un bucket de S3 en AWS y su contenido           |
| upload-templates | Subir las plantillas de CloudFormation a un bucket de S3 |