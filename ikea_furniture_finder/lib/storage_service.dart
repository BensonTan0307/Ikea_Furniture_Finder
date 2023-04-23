import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'dart:io';
import 'dart:math';

class Storage {

  final firebase_storage.FirebaseStorage storage =
      firebase_storage.FirebaseStorage.instance;
  Future<void> uploadFile(
      String filePath,
      String fileName,
      ) async {
    File file = File(filePath);

    try {
      await storage.ref('FurnitureTrainingSet2/$fileName/').putFile(file);
      print("18"+'FurnitureTrainingSet2/$fileName/');
    } on firebase_core.FirebaseException catch (e) {
      print(e);
    }
  }

  Future<String>downloadURL(String imageName) async{
    String downloadURL = await storage.ref('FurnitureTrainingSet2/$imageName+/').getDownloadURL();
    print("26"+downloadURL);
    return downloadURL;
  }

  Future<List<String>> getJpegFileUrls(String prediction) async {
    List<String> imageUrls = [];
    try {
      firebase_storage.ListResult result =
      await firebase_storage.FirebaseStorage.instance
          .ref('FurnitureTrainingSet2/$prediction/')
          .listAll();

      for (firebase_storage.Reference ref in result.items) {
        if (ref.name.endsWith('.jpeg')) {
          String downloadUrl = await ref.getDownloadURL();
          imageUrls.add(downloadUrl);
        }
      }
    } catch (e) {
      print(e);
    }
    return imageUrls;
  }

  Future<List<String>> getRandomImages(String prediction) async {
    firebase_storage.ListResult listResult =
    await firebase_storage.FirebaseStorage.instance
        .ref('FurnitureTrainingSet2/$prediction'+'/')
        .listAll();
    List<firebase_storage.Reference> images = listResult.items;
    List<String> imageUrls = [];

    // Shuffle the images and pick the first five
    images.shuffle();
    for (int i = 0; i < 5 && i < images.length; i++) {
      if (images[i].name.endsWith('.jpeg')) { // only add JPEG files
        String downloadUrl = await images[i].getDownloadURL();
        imageUrls.add(downloadUrl);
      }
    }

    return imageUrls;
  }

}