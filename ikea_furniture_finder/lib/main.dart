import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ikea_furniture_finder/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'dart:convert';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:connectivity/connectivity.dart';


final Storage storage = Storage();

Future main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Future.delayed(const Duration(seconds: 3));
  FlutterNativeSplash.remove();
  await Firebase.initializeApp();
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult != ConnectivityResult.wifi && connectivityResult != ConnectivityResult.mobile) {
    // If not connected to WiFi or mobile data, show an error message and exit the app
    runApp(MaterialApp(
      home: Builder(
        builder: (context) => AlertDialog(
          title: Text('No Internet Connection'),
          content: Text('Please connect to a WiFi or mobile data network to use Ikea Furniture Finder.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => exit(0),
            ),
          ],
        ),
      ),
    ));
    return;
  }

  runApp(MaterialApp(
    home: MyApp(),
  ));
}

Future<void> sendImageToApi(File? image, BuildContext context) async {
  if (image == null) return;

  // Get an App Check token
  final appCheckToken = await FirebaseAppCheck.instance.getToken();

  // Send the image to the API endpoint
  final url = Uri.parse("https://getprediction3-biptoq2fwq-uw.a.run.app");
  final request = http.MultipartRequest("POST", url);
  request.headers.addAll({'Authorization': 'Bearer $appCheckToken'});
  request.files.add(await http.MultipartFile.fromPath("file", image.path));
  final response = await request.send();
  final responseBody = await response.stream.bytesToString();
  final jsonMap = json.decode(responseBody);
  final prediction = jsonMap['prediction'];

  // Modify the prediction value to include the path
  final String furnitureType = prediction;
  final furnitureTypeWithoutPrefix = furnitureType.split("_")[1]; // "Sofas"
  final String furnitureTypeWithoutPrefixAndSplit = furnitureTypeWithoutPrefix.split(RegExp(r'(?=[A-Z])')).join(' ');
  print(furnitureTypeWithoutPrefixAndSplit);//"Chairs Stoolsbenches"
  print(furnitureType); // Prints "3_Sofas"

  // Show a message to the user
  final message = furnitureType.isNotEmpty ? "Image sent successfully" : "Failed to send image";
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: 2),
    ),
  );

  final storage = FirebaseStorage.instance;
  final ref = storage.ref().child('FurnitureTrainingSet2/$furnitureType');

  // show a transparent grey overlay over the screen
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    },
  );

  final result = await ref.listAll();

  // Get a list of all the JPEG file URLs under the specified directory
  final List<String> jpegUrls = await Future.wait(result.items
      .where((item) => item.name.toLowerCase().endsWith('.jpeg'))
      .map((item) => item.getDownloadURL())
      .toList());

  // Shuffle the list of JPEG URLs
  jpegUrls.shuffle();

  // Get the top 10 URLs and show them in a horizontally scrollable view
  final top10Urls = jpegUrls.take(10).toList();
  final List<Widget> images = await Future.wait(top10Urls.map((url) async {
    final response = await http.get(Uri.parse(url));
    final bytes = response.bodyBytes;
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
      child: Image.memory(
        bytes,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/error.png',
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }));

  // remove the grey overlay and show the dialog
  Navigator.of(context).pop(); // remove the grey overlay
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Here\'s the $furnitureTypeWithoutPrefixAndSplit I suggest for you.'),
      content: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: images,
        ),
      ),
      actions: [
        TextButton(
          child: Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );

}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return MyAppState();
  }
}

class MyAppState extends State<MyApp>{

  final colorYellow = Color.fromRGBO(255, 218, 26, 1);
  final colorBlue = Color.fromRGBO(0, 81, 186, 1);

  List<AssetImage> _backgroundImages = [
    AssetImage('assets/background_image_1.png'),
    AssetImage('assets/background_image_2.png'),
    AssetImage('assets/background_image_3.png'),
    AssetImage('assets/background_image_4.png'),
    AssetImage('assets/background_image_5.png'),
    AssetImage('assets/background_image_6.png'),];

  int _currentIndex = 0;
  int _nextIndex = 1;

  @override
  void initState() {
    super.initState();
    // Start the timer to switch the background image every 3 seconds
    Timer.periodic(Duration(seconds: 3), (timer) {
      setState(() {
        _currentIndex = _nextIndex;
        _nextIndex = (_nextIndex + 1) % _backgroundImages.length;
      });
    });
  }


  File?image;
  Future pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;

      final imageTemporary = File(image.path);
      setState(() => this.image = imageTemporary);
    } on PlatformException catch (e) {
      print("Fail to pick image: $e");
      // TODO
    }
  }

  Future<Size> _getImageSize(ImageProvider imageProvider) async {
    Completer<Size> completer = Completer();
    Image image = Image(image: imageProvider);
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
            (ImageInfo imageInfo, bool _) {
          completer.complete(Size(
            imageInfo.image.width.toDouble(),
            imageInfo.image.height.toDouble(),
          ));
        },
      ),
    );
    return completer.future;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ikea Furniture Finder',
          style: TextStyle(color: Color.fromRGBO(0, 81, 186, 1),
              fontSize: 32,
              //fontWeight: FontWeight.bold,
              fontFamily: 'IKEA-Sans'
          ),

        ),
        centerTitle: true,
        backgroundColor: colorYellow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight:  Radius.circular(30)
          ),
        ),
      ),

      body: Stack(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: _backgroundImages[_currentIndex],
                  fit: BoxFit.cover,
                ),
              ),
            ),
            AnimatedContainer(
              duration: Duration(seconds: 3),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: _backgroundImages[_nextIndex],
                  fit: BoxFit.cover,
                ),
              ),
              onEnd: () {
                setState(() {
                  _currentIndex = _nextIndex;
                  _nextIndex = (_nextIndex + 1) % _backgroundImages.length;
                });
              },
            ),
            Positioned.fill(
              child: Column(
                children: <Widget>[
                  Container(
                      height: 360,
                      width: 360,
                      padding: EdgeInsets.all(32.0),
                      margin: EdgeInsets.fromLTRB(0, 30, 0, 0),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          image != null ? FutureBuilder<Size>(
                            future: _getImageSize(FileImage(image!)),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                Size imageSize = snapshot.data!;
                                if (imageSize.width > imageSize.height) {
                                  // Landscape image
                                  return Image.file(
                                    image!,
                                    width: double.infinity,
                                    height: 250,
                                    fit: BoxFit.fitWidth,
                                  );
                                } else {
                                  // Portrait image
                                  return Image.file(
                                    image!,
                                    height: 250,
                                    width: null,
                                    fit: BoxFit.fitHeight,
                                  );
                                }
                              } else {
                                return CircularProgressIndicator();
                              }
                            },
                          ) :Image(
                            image:AssetImage('assets/ikeaapp.png'),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ],
                      )
                  ),
                  const SizedBox(height: 0),

                  buildButton(
                    title:'Pick From Gallery',
                    icon: Icons.image_outlined,
                    onClicked:()=>pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(height: 24),
                  buildButton(
                    title:'Pick From Camera',
                    icon: Icons.camera_alt_outlined,
                    onClicked:()=>pickImage(ImageSource.camera),
                  ),
                  const SizedBox(height: 24),

                  buildButton(
                    title: 'Submit',
                    icon: Icons.send,
                    onClicked: () async {
                      sendImageToApi(image, context);
                      // Show dialog

                    },
                  ),

                  Spacer(),

                ],
              ),
            ),

          ]
      ),
    );
  }

  Widget buildButton({
    required String title,
    required IconData icon,
    required VoidCallback onClicked,
  })=>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(56),
          primary: Colors.white,
          onPrimary: Colors.black,
          textStyle: TextStyle(fontSize: 20, fontFamily: 'IKEA-Sans' ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 16),
            Text(title),
          ],
        ),
        onPressed: onClicked,
      );
}

