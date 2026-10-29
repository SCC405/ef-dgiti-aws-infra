# Guion de narración — sincronizado con `EF-DGITI-video-sin-voz.mp4`

**Duración del video: 9:05.** El video ya está grabado y editado. Ustedes solo ponen la
voz. Cada bloque dice **desde qué segundo** se habla, **qué se ve en pantalla** en ese
momento y **qué decir**. Arriba de cada escena el video muestra el nombre de quien habla
(Santiago en azul, Erick en verde, Nicolay en naranja), así que es fácil no perderse.

> **Cómo grabar la voz**
> 1. Abran el video en el editor que quieran (CapCut, Clipchamp de Windows, DaVinci o
>    el mismo PowerPoint) y graben la voz encima, cada uno su parte.
> 2. No lean palabra por palabra: lean el bloque dos veces, quédense con la idea y
>    díganlo con sus palabras, mirando la pantalla. Los segundos son la referencia;
>    si se corren uno o dos segundos no pasa nada.
> 3. Hablen tranquilos: cada bloque tiene más tiempo del que se necesita.

> **Importante (lo exige el profesor):** el video está grabado en la cuenta de AWS
> Academy de Santiago. Erick y Nicolay **no deben decir "mi cuenta"** sobre estas
> pantallas. La forma segura de cumplir la regla es que cada uno grabe aparte un clip de
> 20–30 s entrando a **su** Learner Lab y mostrando **su** ID de cuenta (ver
> `docs/PREPARACION-VIDEO.md`) y se pegue justo después de su tarjeta de presentación.
> Si lo hacen, los tiempos de ese integrante se corren lo que dure su clip.

---

## 00:00 – 00:05 · Tarjeta de título  (Santiago)

> "Hola profe, somos Erick, Nicolay y Santiago, y esta es nuestra evaluación final."

---

## SANTIAGO · 00:05 – 03:06

### 00:05 · Tarjeta "Santiago"
> "Yo arranco con la arquitectura y la infraestructura como código."

### 00:08 · Laboratorio y consola
*En pantalla: el Learner Lab en verde; luego la consola de AWS y el menú de cuenta con el ID 9750-5015-1395.*
> "Estamos en mi cuenta de AWS Academy: el laboratorio está activo, y acá en la consola
> se ve mi número de cuenta, 9750-5015-1395. Todo lo que vamos a mostrar vive aquí."

### 00:26 · Diagrama completo
*En pantalla: el diagrama entero.*
> "Este es el diagrama de la solución, hecho con los íconos oficiales de AWS."

### 00:31 · Zoom: usuarios → Internet Gateway → balanceador
> "El usuario entra por Internet al Internet Gateway y de ahí al Application Load
> Balancer, que es lo único expuesto públicamente. El balanceador revisa cada 15 segundos
> el endpoint /health de cada instancia para saber a cuáles mandarles tráfico."

### 00:44 · Zoom: la VPC completa
> "La VPC la dividimos en tres capas y todo está repetido en dos zonas de
> disponibilidad. Arriba la capa pública, con el balanceador y el NAT Gateway; en el
> medio la capa de aplicación; y abajo la capa de datos, que ni siquiera tiene ruta a
> Internet."

### 00:55 · Zoom: Auto Scaling Group
> "Las EC2 corren dentro de un Auto Scaling Group en subredes privadas: mínimo dos, una
> por zona, y hasta cuatro si la CPU pasa del 50 %. Si una instancia o una zona se cae,
> la otra sigue atendiendo y el grupo la reemplaza solo."

### 01:05 · Zoom: capa de datos
> "La base es RDS PostgreSQL: la principal en la zona A recibe las escrituras, y una
> réplica de lectura en la zona B atiende las consultas. Así repartimos la carga y
> tenemos los datos en dos zonas."

### 01:15 · Zoom: Security Groups
> "En seguridad, los Security Groups van encadenados: el balanceador acepta el 80 desde
> Internet, las EC2 solo aceptan el 8000 desde el balanceador, y la base solo el 5432
> desde las EC2. Nadie se puede saltar una capa."

### 01:25 · Zoom: almacenamiento, secretos y monitoreo
> "La contraseña de la base la genera Terraform y queda cifrada en SSM Parameter Store;
> las instancias la leen con su rol, nunca está en el código. Los discos son EBS y todo
> se monitorea en CloudWatch con alarmas."

### 01:32 · Zoom: flujo CI/CD
> "Y aquí abajo, en naranja, el despliegue: un push a GitHub dispara GitHub Actions,
> que prueba, valida y actualiza las instancias. Eso lo muestra Erick."

### 01:41 · Diagrama completo otra vez
> "Esa es la arquitectura; ahora, cómo la construimos."

### 01:46 · Archivos de Terraform en GitHub
*En pantalla: carpeta `infra/`, luego `main.tf` bajando por las secciones, y al final `user_data.sh`.*
> "Toda la infraestructura está como código en la carpeta infra: provider.tf con el
> proveedor de AWS, variables.tf con todo lo configurable, outputs.tf con lo que
> necesitamos después, el tfvars de ejemplo, y main.tf, organizado por secciones: red,
> seguridad, base de datos, cómputo, balanceo y monitoreo. Y el user_data.sh es lo que
> ejecuta cada EC2 al arrancar: instala Docker, clona este repositorio y levanta la API."

### 02:16 · `terraform init`
*En pantalla: CloudShell.*
> "Lo ejecutamos desde CloudShell, dentro de la cuenta, así no hay llaves guardadas en
> ningún computador. Primero terraform init, que descarga los proveedores."

### 02:25 · `terraform plan`
> "Después terraform plan, que compara el código con lo que existe en AWS. Como ya está
> desplegado, dice No changes: la infraestructura es exactamente igual al código. La
> primera vez fueron 48 recursos y tardó unos veinte minutos; lo más lento fue la
> réplica de RDS."

### 02:37 · `terraform apply`
> "El apply lo confirma: Apply complete, cero agregados, cero cambios, cero destruidos."

### 02:58 · `terraform output`
> "Y terraform output nos da la URL del balanceador, la de Swagger, el nombre del Auto
> Scaling Group y los endpoints de la base principal y la réplica. Le paso a Erick."

---

## ERICK · 03:06 – 05:39

### 03:06 · Tarjeta "Erick"
> "Gracias, Santiago. Yo voy a mostrar el servicio funcionando y el pipeline."

### 03:09 · Instancias EC2
*En pantalla: dos instancias `ef-dgiti-app` en ejecución, una en us-east-1a y otra en us-east-1b; detalle de red sin IP pública.*
> "Estas son las dos instancias de la aplicación, una en cada zona. Fíjense que no
> tienen IP pública: solo se llega a ellas a través del balanceador."

### 03:24 · `/health`
*En pantalla: la respuesta de /health por el balanceador.*
> "Este es el endpoint de validación, /health. Responde status ok y nos dice qué
> instancia contestó."

### 03:31 · `/status`, recargando
*En pantalla: /status se recarga y cambia de instancia y de zona.*
> "Ahora /status, que trae más información: la instancia, la zona, la versión
> desplegada, que es el commit de GitHub, y el estado de la base principal y la réplica,
> las dos en ok. Recargo... y cambia de instancia y de zona. Recargo otra vez... vuelve a
> la otra. Ese es el balanceador repartiendo el tráfico."

### 03:54 · Swagger: POST
*En pantalla: Swagger, POST /api/items con "Firewall Fortinet 60F", respuesta 201.*
> "FastAPI nos genera esta documentación con Swagger. Creo un ítem con un POST... la
> respuesta es 201 y dice written_to: primary, o sea que se escribió en la base
> principal."

### 04:17 · Swagger: GET
*En pantalla: GET /api/items, `read_from: replica` y el ítem nuevo de primero.*
> "Ahora lo consulto con el GET: read_from: replica. La lectura sale de la réplica, en
> la otra zona, y el ítem que acabamos de crear ya aparece. La replicación funciona."

### 04:36 · curl
> "Y lo mismo desde la terminal con curl: HTTP 200."

### 04:44 · Pipeline: el flujo
*En pantalla: la ejecución de GitHub Actions con los cuatro jobs en verde.*
> "Ahora el pipeline. Cada push a main dispara estas cuatro etapas en GitHub Actions, y
> acá están todas en verde."

### 04:53 · Job 1: lint y pruebas
*En pantalla: el log de pytest con las 12 pruebas PASSED y la cobertura.*
> "La primera revisa el código con ruff y corre las pruebas con pytest: son doce pruebas
> unitarias y de integración, todas pasan, con 88 % de cobertura. Las de integración
> levantan la API completa contra una base de datos real."

### 05:11 · Job 2: Docker
> "La segunda construye la imagen Docker y le hace una prueba de humo: levanta el
> contenedor y le pega a /health, /status y a un POST."

### 05:23 · Job 3: Terraform
> "La tercera valida Terraform con fmt y validate: si alguien rompe el código de la
> infraestructura, no pasa. Y la cuarta despliega a AWS con las credenciales guardadas
> como secretos de GitHub, reemplazando las instancias de a una para no tumbar el
> servicio. Le paso a Nicolay."

---

## NICOLAY · 05:39 – 09:05

### 05:39 · Tarjeta "Nicolay"
> "Yo voy a ponerlo a prueba con carga y mostrar el monitoreo."

### 05:42 · Target group
*En pantalla: `ef-dgiti-tg` con 2 destinos en buen estado, us-east-1a y us-east-1b.*
> "Este es el grupo de destino del balanceador: dos instancias registradas, las dos
> Healthy, una en cada zona."

### 05:58 · Reparto del balanceador
*En pantalla: 20 solicitudes a /status y el conteo final.*
> "Mando veinte solicitudes seguidas y cuento quién respondió: 11 una y 9 la otra. El
> balanceador reparte parejo entre las dos zonas."

### 06:12 · k6 en vivo
*En pantalla: k6 corriendo con la barra de usuarios virtuales; al final, el resumen.*
> "Ahora la prueba de carga con k6. Sube hasta 120 usuarios virtuales en un minuto y
> medio; el 70 % de las peticiones van a /api/stress, que hace cálculo pesado de CPU.
> Lo acelero un poco... Resultado: unas 7.000 solicitudes, 78 por segundo, tiempo
> promedio de 303 milisegundos, p95 de 864 y 0,01 % de errores."

### 06:52 · CloudWatch: el primer pico
*En pantalla: dashboard `ef-dgiti-dashboard` entre 07:12 y 07:42 UTC: dos picos.*
> "Para ver el comportamiento bajo saturación, antes corrimos dos veces una prueba más
> fuerte: seis minutos hasta 150 usuarios. En el primer pico, con dos instancias, las
> solicitudes por minuto suben y se quedan planas en unas 5.500: ese es el techo. Y el
> tiempo de respuesta se dispara: el p95 llega a dos segundos."

### 07:13 · CloudWatch: CPU y Auto Scaling
*En pantalla: CPU del ASG cruzando la línea roja del 50 % y llegando a 90 %; instancias de 2 a 4.*
> "¿Por qué? La CPU de las instancias pasa la línea del 50 % y se queda en 90: las
> t3.micro tienen solo dos vCPU y ese es el cuello de botella. A los tres minutos la
> alarma de target tracking se dispara y el Auto Scaling sube de 2 a 4 instancias.
> Nadie tocó nada. En el segundo pico, ya con cuatro, se atienden más de 11.000
> solicitudes por minuto, el doble."

### 07:31 · CloudWatch: la prueba de ahora y RDS
*En pantalla: el dashboard con los últimos 30 minutos: a la derecha, el pico de CPU de la prueba que acabamos de correr; abajo, RDS.*
> "Esta es la vista de ahora: el pico de la derecha es la prueba que acabamos de correr."
>
> "Abajo, la base de datos casi no se inmuta: su CPU no pasa del 10 %, porque la carga
> está en la aplicación. El retraso de la réplica sube en diente de sierra porque RDS lo
> mide desde la última transacción: si no hay escrituras crece solo y se reinicia cada
> cinco minutos. Lo importante es que lo que escribimos aparece de una en la réplica."

### 08:02 · Comparación 2 contra 4 instancias
*En pantalla: la tabla de resultados del README.*
> "Comparando las dos pruebas completas: con cuatro instancias pasamos de 77 a 123
> solicitudes por segundo, un 60 % más; el p95 bajó de dos segundos a medio segundo, un
> 76 % menos; y los errores quedaron en cero. El escalado horizontal detrás del
> balanceador funciona. Lo que mejoraríamos: la instancia nueva tarda unos cinco minutos
> en quedar sana porque construye la imagen Docker al arrancar; con una AMI ya preparada
> sería mucho más rápido."

### 08:32 · Auto Scaling: actividad
*En pantalla: la política `ef-dgiti-cpu-target` y el historial filtrado por TargetTracking.*
> "Y esta es la evidencia en el Auto Scaling: la política de target tracking al 50 % de
> CPU, y en el historial, las alarmas que subieron la capacidad de 2 a 4 y después la
> bajaron de 4 a 3 y a 2 cuando terminó la carga."

### 08:57 · Tarjeta "Gracias"
> "En resumen: todo está en Terraform, se prueba y se despliega con GitHub Actions,
> aguanta la caída de una instancia gracias a las dos zonas, y bajo carga el balanceador
> reparte y el Auto Scaling escala. Gracias, profe."
