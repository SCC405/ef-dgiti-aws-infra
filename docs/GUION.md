# Guion del video — EF DGITI (máximo 10 minutos)

**Duración objetivo: 9:40.** Cada uno habla unos 3 minutos y hace su demostración
**en su propia cuenta** de AWS Academy, como pide el profesor.

| Tramo | Quién | Parte | Criterio de la rúbrica |
|---|---|---|---|
| 00:00 – 03:15 | **Santiago** | Introducción, arquitectura y Terraform | Arquitectura 10 % + IaC 25 % |
| 03:15 – 06:20 | **Erick** | Servicio desplegado y pipeline CI/CD | Servicio 10 % + CI/CD 25 % |
| 06:20 – 09:40 | **Nicolay** | Prueba de carga, balanceador y CloudWatch | Desempeño y monitoreo 30 % |

> **Cómo leer este guion.** El texto entre comillas es una guía, no hay que decirlo
> palabra por palabra. Léanlo dos o tres veces, quédense con la idea y díganlo con sus
> palabras. Lo que está en **[corchetes]** es lo que se hace en pantalla en ese momento.
> Si un segundo se corre un poco no pasa nada: lo importante es no pasarse de 10:00.

> **Tip de grabación.** Graben cada parte por separado (OBS o Win + Alt + R) y después
> peguen los tres clips. Así, si alguien se equivoca, repite solo su parte.

---

## SANTIAGO — 00:00 a 03:15

### 00:00 – 00:25 · Presentación y cuenta

**[Pantalla: AWS Academy → Learner Lab con el punto verde. Clic en "AWS" → la consola abre. Señalar con el mouse el "ID de cuenta" arriba a la derecha.]**

> "Hola profe, somos Erick, Nicolay y Santiago. Les vamos a mostrar una API que montamos
> en AWS de punta a punta: la infraestructura con Terraform, el pipeline en GitHub
> Actions, y las pruebas de carga con monitoreo en CloudWatch. Yo arranco desde mi
> cuenta de AWS Academy: acá ven el laboratorio activo y arriba mi número de cuenta."

### 00:25 – 01:45 · Arquitectura (diagrama)

**[Pantalla: `docs/arquitectura.png` a pantalla completa. Ir señalando con el mouse cada parte que se nombra.]**

> "Este es el diagrama, con los íconos oficiales de AWS. El usuario entra por
> Internet al **Internet Gateway** y de ahí al **Application Load Balancer**, que es lo
> único expuesto públicamente.
>
> La VPC la dividimos en **tres capas** y todo está repetido en **dos zonas de
> disponibilidad**, la 1a y la 1b. Arriba, las subredes **públicas**: ahí solo viven el
> balanceador y el NAT Gateway. En el medio, las subredes **privadas de aplicación**,
> donde corren las EC2 dentro de un **Auto Scaling Group**: mínimo dos instancias,
> una por zona, y puede crecer hasta cuatro cuando la CPU pasa del 50 %. Y abajo, la
> capa de **datos**, que ni siquiera tiene ruta a Internet: ahí está **RDS PostgreSQL**,
> la principal en la zona A y una **réplica de lectura** en la zona B.
>
> ¿Por qué así? Si se cae una instancia o una zona completa, la otra sigue atendiendo
> y el Auto Scaling la reemplaza solo. Las escrituras van a la principal y las lecturas a
> la réplica, para repartir la carga de la base de datos.
>
> En seguridad usamos **Security Groups encadenados**: el del balanceador acepta el
> puerto 80 desde Internet; el de las EC2 solo acepta el 8000 **desde el Security Group
> del balanceador**; y el de la base solo acepta el 5432 **desde el de las EC2**. Nadie
> se puede saltar una capa. La contraseña de la base la genera Terraform y queda cifrada
> en **SSM Parameter Store**, nunca en el código.
>
> Y abajo a la izquierda, en naranja, está el flujo de despliegue: el push a GitHub
> dispara GitHub Actions, que es lo que les va a mostrar Erick."

### 01:45 – 02:15 · Archivos de Terraform

**[Pantalla: el repo en GitHub → carpeta `infra/`. Abrir `main.tf` y bajar despacio pasando por los títulos 1. RED, 2. SEGURIDAD, 3. BASE DE DATOS...]**

> "Toda esta infraestructura está como código. En la carpeta `infra` tenemos
> `provider.tf` con el proveedor de AWS, `variables.tf` con todo lo configurable
> —CIDRs, tipo de instancia, mínimos y máximos del Auto Scaling—, `main.tf` con los
> recursos organizados por secciones: red, seguridad, base de datos, cómputo, balanceo
> y monitoreo; `outputs.tf` con lo que necesitamos después, como la URL; el
> `terraform.tfvars.example`, y el `user_data.sh`, que es lo que corre cada EC2 al
> arrancar: instala Docker, clona este repositorio y levanta la API."

### 02:15 – 03:05 · terraform init / plan / apply / output

**[Pantalla: consola AWS → CloudShell (icono `>_`). Ya debe estar en `~/ef-dgiti-aws-infra/infra`. Escribir cada comando y esperar el resultado.]**

```bash
terraform init
```

> "Lo ejecutamos desde CloudShell, dentro de mi cuenta, así no hay llaves guardadas en
> ningún computador. `terraform init` descarga los proveedores de AWS y random..."

```bash
terraform plan
```

> "...el `plan` compara el código con lo que existe en AWS. Como ya lo desplegamos, dice
> **No changes**: la infraestructura está exactamente igual al código. La primera vez
> el plan fueron 48 recursos y el apply tardó unos 20 minutos; lo más lento fue la
> réplica de RDS."

```bash
terraform apply -auto-approve
```

> "El `apply` confirma: cero cambios."

```bash
terraform output
```

> "Y con `output` sacamos lo importante: la URL del balanceador, la de Swagger, el
> nombre del Auto Scaling Group, los endpoints de la base principal y de la réplica, y
> el link al dashboard de CloudWatch."

### 03:05 – 03:15 · Paso a Erick

> "Con esto la infraestructura queda arriba. Erick, te la paso para que muestres el
> servicio funcionando."

---

## ERICK — 03:15 a 06:20

### 03:15 – 03:35 · Su cuenta

**[Pantalla: AWS Academy de Erick con el lab en verde → consola → señalar su ID de cuenta → EC2 → Instancias: dos `ef-dgiti-app` en "En ejecución", una en us-east-1a y otra en us-east-1b.]**

> "Gracias, Santiago. Yo estoy en mi propia cuenta de AWS Academy; acá está mi ID de
> cuenta. Desplegamos el mismo código en mi cuenta, y acá ven las dos instancias de la
> aplicación corriendo, cada una en una zona distinta."

### 03:35 – 04:15 · Endpoint de validación en el navegador

**[Pantalla: pestaña con `http://<alb>/health`. Luego `http://<alb>/status` y presionar F5 tres o cuatro veces despacio.]**

> "Este es el endpoint de validación, `/health`: responde `status ok`. Es el mismo que
> el balanceador consulta cada 15 segundos para saber si una instancia está sana.
>
> Ahora `/status`. Fíjense en el `instance_id` y la zona... recargo... **cambió de
> instancia** y de zona. Recargo otra vez... vuelve a la primera. Ese es el balanceador
> repartiendo el tráfico. Abajo también se ve que la base **principal** y la **réplica**
> responden `ok`, y la `version` es el commit de GitHub que está desplegado."

### 04:15 – 04:55 · Swagger: escribir y leer

**[Pantalla: `http://<alb>/docs`. Abrir `POST /api/items` → Try it out → nombre `"Firewall Fortinet"` → Execute. Luego `GET /api/items` → Try it out → Execute.]**

> "FastAPI nos genera Swagger automáticamente. Creo un ítem con un POST... respuesta
> **201**, y fíjense que dice `written_to: primary`: se escribió en la base principal.
>
> Ahora consulto la lista con el GET: `read_from: replica`. La lectura sale de la
> réplica, en la otra zona, y ya aparece el ítem que acabamos de crear. Eso confirma que
> la replicación está funcionando."

### 04:55 – 05:05 · curl

**[Pantalla: PowerShell.]**

```powershell
curl.exe http://<alb>/health
```

> "Y lo mismo desde la terminal con curl: responde 200."

### 05:05 – 06:10 · Pipeline CI/CD

**[Pantalla: GitHub → pestaña Actions → la última ejecución en verde. Mostrar el gráfico de los 4 jobs. Clic en "1 - Lint y pruebas" → desplegar el paso "Pruebas unitarias e integración". Volver, mostrar el artefacto "reporte-pruebas". Clic en "4 - Despliegue". Por último, Settings → Environments → aws-academy → secretos (salen ocultos).]**

> "Ahora el pipeline. Cada vez que hacemos push a `main`, GitHub Actions corre cuatro
> etapas.
>
> La **uno** valida el código con `ruff` y corre las pruebas con `pytest`: acá ven
> las **12 pruebas pasando**, unitarias e integración, porque levantan la API completa
> contra una base de datos real en SQLite. Queda un reporte de las pruebas como
> artefacto.
>
> La **dos** construye la imagen Docker y le hace una prueba rápida: levanta el
> contenedor y le pega a `/health`, `/status` y a un POST.
>
> La **tres** valida Terraform: `fmt`, `init` y `validate`. Si alguien rompe el código
> de la infraestructura, el pipeline no deja pasar.
>
> Y la **cuatro** despliega. Se conecta a AWS con credenciales guardadas como
> **secretos de GitHub** —acá ven que están ocultos, nunca aparecen en el código ni en
> los logs— y hace un **rolling update** del Auto Scaling: va cambiando las
> instancias de a una, nunca baja del 50 % sanas, y cada instancia nueva clona el último
> commit. O sea, se actualiza **sin tumbar el servicio**. Al final hace una prueba
> contra el balanceador."

### 06:10 – 06:20 · Paso a Nicolay

> "Ya vimos que funciona. Ahora Nicolay lo va a poner a prueba con carga."

---

## NICOLAY — 06:20 a 09:40

### 06:20 – 06:35 · Su cuenta

**[Pantalla: AWS Academy de Nicolay con el lab en verde → consola → señalar su ID de cuenta.]**

> "Bueno, yo estoy en mi cuenta de AWS Academy, acá está mi número de cuenta. La idea
> es comprobar cómo se comporta todo esto cuando le llega tráfico de verdad."

### 06:35 – 07:05 · El balanceador funcionando

**[Pantalla: EC2 → Grupos de destino → `ef-dgiti-tg` → pestaña Destinos: 2 instancias "Healthy" en 1a y 1b. Luego PowerShell:]**

```powershell
powershell -ExecutionPolicy Bypass -File load-tests\balance-check.ps1 -Url http://<alb> -N 20
```

> "Primero, el grupo de destino del balanceador: dos instancias **Healthy**, una por
> zona. Con este script mando 20 peticiones seguidas y cuento quién respondió cada una:
> **50 % y 50 %**, cero fallos. El balanceador reparte parejo."

### 07:05 – 07:15 · Lanzar la prueba de carga

**[Pantalla: PowerShell.]**

```powershell
k6 run -e PERFIL=corto -e BASE_URL=http://<alb> load-tests/k6-load.js
```

> "Ahora lanzo k6. Este perfil sube a **120 usuarios virtuales** en un minuto y medio.
> El 70 % de las peticiones van a `/api/stress`, que hace cálculo pesado de CPU; el resto
> son lecturas a la réplica y `/status`. Mientras corre, vamos a CloudWatch."

### 07:15 – 08:20 · CloudWatch (dashboard)

**[Pantalla: CloudWatch → Paneles → `ef-dgiti-dashboard`, rango "1 h". Se ven los dos "picos" de las pruebas que se corrieron antes de grabar. Señalar cada gráfica que se nombra.]**

> "Este dashboard también lo crea Terraform. Antes de grabar corrimos dos veces la misma
> prueba: seis minutos subiendo hasta **150 usuarios**. Por eso se ven dos picos.
>
> Miren el **primer pico**, con dos instancias. Las **solicitudes por minuto** suben y se
> quedan **planas en unas 5.500**: no importa que lleguen más usuarios, el sistema no
> atiende más. Ese es el **punto de saturación**. ¿Por qué? Abajo está la **CPU** del Auto
> Scaling Group: pasa la línea del 50 % y se queda en **90 %**. Las t3.micro tienen solo
> dos vCPU y `/api/stress` es puro cálculo, entonces el cuello de botella es la CPU de la
> capa de aplicación. Y se nota en el **tiempo de respuesta**: el p95 se va a **2
> segundos** y el p99 a más de 3.
>
> Ahora, después de unos tres minutos con la CPU alta, la alarma de **target tracking**
> se dispara, y en esta gráfica las **instancias del Auto Scaling pasan de 2 a 4**. Nadie
> tocó nada: AWS lo hizo solo.
>
> El **segundo pico** es la misma prueba, pero ya con cuatro instancias: ahora llega a
> **11.200 solicitudes por minuto, el doble**, y la latencia apenas se mueve.
>
> En **códigos HTTP** prácticamente todo es 2XX, y en **instancias sanas** se ve cómo
> entran las dos nuevas. Abajo, la base de datos casi no se inmuta: la carga es de CPU en
> la aplicación, no en RDS, y la réplica va prácticamente al día."

### 08:20 – 08:55 · Resultado de k6 y comparación

**[Pantalla: volver a PowerShell, al resumen final de k6 que acaba de terminar. Después abrir `load-tests/results/` y poner lado a lado `summary-2-instancias.txt` y `summary-4-instancias.txt`, o mostrar la tabla del README.]**

> "Ya terminó la prueba en vivo: [leer de la pantalla los usuarios virtuales, las
> solicitudes, el promedio, el p95 y el porcentaje de errores]."
>
> "Y esta es la comparación de las dos pruebas completas:
>
> | | 2 instancias | 4 instancias |
> |---|---|---|
> | Solicitudes por segundo | 77 | **123** |
> | Tiempo promedio | 638 ms | **212 ms** |
> | p95 | 2.057 ms | **498 ms** |
> | Errores | 0,05 % | **0 %** |
>
> Con el doble de instancias atendimos **60 % más solicitudes por segundo** y el p95 bajó
> **un 76 %**, de dos segundos a medio segundo. Eso confirma que el escalado horizontal
> detrás del balanceador funciona: el balanceador reparte, y cada instancia nueva suma
> capacidad. Lo único a mejorar: el escalado tarda unos 5 minutos entre que se dispara la
> alarma y la instancia queda sana, porque cada EC2 construye la imagen de Docker al
> arrancar. Con una AMI ya preparada ese tiempo bajaría bastante."

### 08:55 – 09:20 · Auto Scaling: la evidencia

**[Pantalla: EC2 → Grupos de Auto Scaling → `ef-dgiti-asg` → pestaña Actividad.]**

> "Y acá está la evidencia del escalado: en la actividad del Auto Scaling aparece
> *'Launching a new EC2 instance'* por la alarma de la política de **target tracking**
> de CPU. Fue AWS el que decidió agregar instancias solo, nadie tocó nada."

### 09:20 – 09:40 · Cierre

> "Entonces, en resumen: la infraestructura está toda en Terraform, se valida y se
> despliega con GitHub Actions, aguanta la caída de una instancia gracias a las dos
> zonas, y bajo carga el balanceador reparte y el Auto Scaling escala. Eso es todo,
> profe, muchas gracias."

---

## De dónde salen los números

Son las dos pruebas completas que se corrieron en la cuenta de Santiago el 29/10/2026
(`load-tests/results/summary-2-instancias.txt` y `summary-4-instancias.txt`). Si Nicolay
repite las pruebas en su cuenta (ver `PREPARACION-VIDEO.md`), los números le van a dar
parecidos pero no iguales: que diga los suyos.

| Métrica (CloudWatch) | Prueba 1 (2 EC2) | Prueba 2 (4 EC2) |
|---|---|---|
| Solicitudes por minuto en el ALB (pico) | ~5.500 (plano: saturado) | 11.242 |
| CPU promedio del ASG (pico) | 91 % | 87 % |
| Alarma de escalado | 07:24:51 UTC → capacidad 2 → 4 | — |
