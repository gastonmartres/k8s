# install-kubernetes.sh

## Introducción

Como muchas otras cosas, este script surge por necesidad, y un poco por capricho.

No encontraba algo que me dejara instalar mas o menos facil kubernetes, sino solo `gists` o algunos scripts que eran bastante basicos. 

Seguramente me faltó buscar un poco mas. 

Por eso se me dió por hacerlo a mi manera, que no quiere decir, ni por casualidad, que sea la mejor forma, la más eficiente ni la más optimizada (todo lo contrario), pero en mi necesidad del día a día, me fué más que suficiente.
Sí. Conozco de la exitencia de minikube, k3s, y otros. Pero este es mío, mi tesoro, mi preciado tesoro... ~~Gollum, Gollum!~~

## Instalación
Este script está orientado a SO basados en `Redhat`, como ser,` CentOS`, `AlmaLinux`, `RockyLinux`, etc.
Más adelante, si lo merece, veré de hacer una versión `debian` based.

El procedimiento de instalacion es de lo mas sencillo. Solo tenemos que clonar el repositorio en el servidor que actuará de `master` y luego ejecutar el script.

```git clone https://github.com/gastonmartres/k8s.git ```

Ya clonado, solo debemos ejecutarlo como `root`: 

```
cd k8s
sudo ./install-kubernetes.sh
```
Al inicio de la ejecucion, el script recopilara alguna informacion que le hace falta para poder instalar todo.
Incluso, podemos obviar algunos pasos, como ser el update de los paquetes del sistema o la instalación de `helm`.

## Disclaimer

A medida que pueda, iré actualizando este script.

Cualquier sugerencia, bienvenida sea.

Cualquiera puede hacer un branch del repositorio, solo se pide que se agregue el este repositorio como origen.