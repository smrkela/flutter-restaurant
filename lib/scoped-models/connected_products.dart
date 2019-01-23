import 'dart:convert';

import 'package:scoped_model/scoped_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/user.dart';
import '../models/auth.dart';

mixin ConnectedProductsModel on Model {
  List<Product> _products = [];
  String _selProductId;
  User _authenticatedUser;
  bool _isLoading = false;
}

mixin ProductsModel on ConnectedProductsModel {
  bool _showFavorites = false;

  List<Product> get allProducts {
    return List.from(_products);
  }

  List<Product> get displayedProducts {
    if (_showFavorites) {
      return _products.where((Product product) => product.isFavorite).toList();
    }

    return List.from(_products);
  }

  Product get selectedProduct {
    return selectedProductId != null
        ? _products
            .firstWhere((Product product) => product.id == selectedProductId)
        : null;
  }

  String get selectedProductId {
    return _selProductId;
  }

  int get selectedProductIndex {
    return _products
        .indexWhere((Product product) => product.id == selectedProductId);
  }

  bool get displayFavoritesOnly {
    return _showFavorites;
  }

  Future<bool> addProduct(
      String title, String description, String image, double price) async {
    _isLoading = true;
    notifyListeners();
    final Map<String, dynamic> productData = {
      'title': title,
      'description': description,
      'image':
          'https://cdn1.medicalnewstoday.com/content/images/articles/321/321618/dark-chocolate-and-cocoa-beans-on-a-table.jpg',
      'price': price,
      'userId': _authenticatedUser.id,
      'userEmail': _authenticatedUser.email
    };

    try {
      final http.Response response = await http.post(
          "https://flutter-products-5ab63.firebaseio.com/products.json?auth=${_authenticatedUser.token}",
          body: json.encode(productData));

      if (response.statusCode != 200 && response.statusCode != 201) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final Map<String, dynamic> responseData = json.decode(response.body);
      final Product newProduct = Product(
          id: responseData['name'],
          title: title,
          description: description,
          price: price,
          image: image,
          userEmail: _authenticatedUser.email,
          userId: _authenticatedUser.id);
      _products.add(newProduct);
      _selProductId = null;
      _isLoading = false;

      notifyListeners();

      return true;
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(
      String title, String description, String image, double price) {
    _isLoading = true;
    notifyListeners();
    final Map<String, dynamic> productData = {
      'title': title,
      'description': description,
      'image':
          'https://cdn1.medicalnewstoday.com/content/images/articles/321/321618/dark-chocolate-and-cocoa-beans-on-a-table.jpg',
      'price': price,
      'userId': _authenticatedUser.id,
      'userEmail': _authenticatedUser.email
    };
    return http
        .put(
            "https://flutter-products-5ab63.firebaseio.com/products/${selectedProduct.id}.json?auth=${_authenticatedUser.token}",
            body: json.encode(productData))
        .then((http.Response response) {
      final Product updatedProduct = Product(
          id: selectedProduct.id,
          title: title,
          description: description,
          image: image,
          price: price,
          userEmail: selectedProduct.userEmail,
          userId: selectedProduct.userId);

      _products[selectedProductIndex] = updatedProduct;
      notifyListeners();
      return true;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return false;
    });
  }

  Future<bool> deleteProduct() {
    _isLoading = true;
    final deletedProductId = selectedProduct.id;

    _products.removeAt(selectedProductIndex);
    _selProductId = null;
    notifyListeners();
    return http
        .delete(
            "https://flutter-products-5ab63.firebaseio.com/products/${deletedProductId}.json?auth=${_authenticatedUser.token}")
        .then((http.Response response) {
      _isLoading = false;

      notifyListeners();
      return true;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return false;
    });
  }

  Future<Null> fetchProducts() {
    _isLoading = true;
    notifyListeners();
    return http
        .get(
            "https://flutter-products-5ab63.firebaseio.com/products.json?auth=${_authenticatedUser.token}")
        .then<Null>((http.Response response) {
      final List<Product> fetchedProducts = [];
      final Map<String, dynamic> productListData = json.decode(response.body);

      if (productListData == null) {
        _products = [];
      } else {
        productListData.forEach((String key, dynamic productData) {
          final Product product = Product(
              id: key,
              title: productData['title'],
              description: productData['description'],
              image: productData['image'],
              price: productData['price'],
              userEmail: productData['userEmail'],
              userId: productData['userId']);
          fetchedProducts.add(product);
        });

        _products = fetchedProducts;
      }

      _isLoading = false;

      notifyListeners();
      _selProductId = null;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
    });
  }

  void toggleProductFavoriteStatus() {
    final Product selectedProduct = _products[selectedProductIndex];
    final bool isCurrentlyFavorite = selectedProduct.isFavorite;
    final bool newFavoriteStatus = !isCurrentlyFavorite;
    final Product updatedProduct = Product(
        id: selectedProduct.id,
        title: selectedProduct.title,
        description: selectedProduct.description,
        price: selectedProduct.price,
        image: selectedProduct.image,
        userEmail: selectedProduct.userEmail,
        userId: selectedProduct.userId,
        isFavorite: newFavoriteStatus);

    _products[selectedProductIndex] = updatedProduct;
    notifyListeners();
  }

  void selectProduct(String productId) {
    _selProductId = productId;
    if (productId != null) notifyListeners();
  }

  void toggleDisplayMode() {
    _showFavorites = !_showFavorites;
    notifyListeners();
  }
}

mixin UserModel on ConnectedProductsModel {
  User get user {
    return _authenticatedUser;  
  }

  Future<Map<String, dynamic>> authenticate(String email, String password,
      [AuthMode mode = AuthMode.Login]) async {
    _isLoading = true;
    notifyListeners();

    final Map<String, dynamic> data = {
      'email': email,
      'password': password,
      'returnSecureToken': true
    };

    String url = mode == AuthMode.Login
        ? 'https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=AIzaSyCbUduhBx8qjF8XfBiUKs6osklHU1JbrbM'
        : 'https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=AIzaSyCbUduhBx8qjF8XfBiUKs6osklHU1JbrbM';

    http.Response response = await http.post(url,
        body: json.encode(data), headers: {'Content-Type': 'application/json'});

    final Map<String, dynamic> responseData = json.decode(response.body);

    bool hasError = true;
    String message = 'Something went wrong.';

    if (responseData.containsKey('idToken')) {
      hasError = false;
      message = 'Authentication succeeded.';
      _authenticatedUser = new User(
          id: responseData['localId'],
          email: email,
          token: responseData['idToken']);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('token', responseData['idToken']);
      prefs.setString('userEmail', email);
      prefs.setString('userId', responseData['localId']);
    } else if (responseData['error']['message'] == 'EMAIL_NOT_FOUND') {
      message = 'This email is not found.';
    } else if (responseData['error']['message'] == 'INVALID_PASSWORD') {
      message = 'The password is invalid.';
    } else if (responseData['error']['message'] == 'EMAIL_EXISTS') {
      message = 'This email already exists.';
    }

    _isLoading = false;
    notifyListeners();

    return {
      'success': !hasError,
      'message': message,
    };
  }

  void autoAuthenticate() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String token = prefs.getString('token');

    if (token != null) {
      String userEmail = prefs.getString('userEmail');
      String userId = prefs.getString('userId');

      _authenticatedUser = new User(id: userId, email: userEmail, token: token);
      notifyListeners();
    }
  }
}

mixin UtilityModel on ConnectedProductsModel {
  bool get isLoading {
    return _isLoading;
  }
}
