import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Este widget es la raíz de tu aplicación.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // Este es el tema de tu aplicación.
        //
        // PRUEBA ESTO: Ejecuta tu aplicación con "flutter run". Verás que la
        // aplicación tiene una barra superior de color púrpura. Luego, sin
        // cerrar la app, intenta cambiar el seedColor del colorScheme de abajo
        // a Colors.green y ejecuta un "hot reload" (guarda los cambios o presiona
        // el botón de hot reload en un IDE compatible con Flutter, o presiona
        // "r" si usaste la línea de comandos).
        //
        // Nota que el contador no se reinicia a cero; el estado de la aplicación
        // no se pierde durante el reload. Para reiniciar el estado, usa hot
        // restart en su lugar.
        //
        // Esto también funciona para el código, no solo para valores: la mayoría
        // de los cambios de código pueden probarse solo con hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // Este widget es la página principal de tu aplicación. Es un widget con estado,
  // lo que significa que tiene un objeto State (definido abajo) que contiene
  // campos que afectan cómo se ve.

  // Esta clase es la configuración del estado. Contiene los valores (en este caso
  // el título) que son proporcionados por el widget padre (en este caso MyApp)
  // y utilizados por el método build del State. Los campos en una subclase de
  // Widget siempre se marcan como "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // Esta llamada a setState le dice al framework de Flutter que algo ha
      // cambiado en este State, lo que provoca que se vuelva a ejecutar el
      // método build de abajo para que la interfaz refleje los valores
      // actualizados. Si cambiáramos _counter sin llamar a setState(), el
      // método build no se ejecutaría de nuevo y parecería que no pasó nada.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Este método se vuelve a ejecutar cada vez que se llama a setState,
    // por ejemplo, como se hace en el método _incrementCounter.
    //
    // El framework de Flutter está optimizado para que volver a ejecutar los
    // métodos build sea rápido, por lo que puedes reconstruir cualquier parte
    // que necesite actualizarse en lugar de cambiar widgets individualmente.
    return Scaffold(
      appBar: AppBar(
        // PRUEBA ESTO: Intenta cambiar el color aquí por un color específico
        // (Colors.amber, por ejemplo) y ejecuta un hot reload para ver cómo
        // cambia el AppBar mientras los demás colores permanecen iguales.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Aquí tomamos el valor del objeto MyHomePage que fue creado por el
        // método build de MyApp y lo usamos para establecer el título del AppBar.
        title: Text(widget.title),
      ),
      body: Center(
        // Center es un widget de diseño. Toma un solo hijo y lo posiciona
        // en el centro de su widget padre.
        child: Column(
          // Column también es un widget de diseño. Toma una lista de widgets
          // hijos y los organiza verticalmente. Por defecto, se ajusta al ancho
          // de sus hijos e intenta ocupar toda la altura disponible.
          //
          // Column tiene varias propiedades para controlar cómo se dimensiona
          // y cómo posiciona a sus hijos. Aquí usamos mainAxisAlignment para
          // centrar los hijos verticalmente; el eje principal es el vertical
          // porque las Column son verticales (el eje cruzado sería horizontal).
          //
          // PRUEBA ESTO: Activa el "debug painting" (elige la acción "Toggle Debug
          // Paint" en el IDE o presiona "p" en la consola) para ver el esquema
          // de cada widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Has presionado el botón esta cantidad de veces:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Incrementar',
        child: const Icon(Icons.add),
      ),
    );
  }
}