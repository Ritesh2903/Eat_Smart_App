import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:grocery/screens/cart/cart_widget.dart';
import 'package:grocery/widgets/text_widget.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../consts/firbase_consts.dart';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';
import '../../services/global_methods.dart';
import '../../services/utils.dart';
import '../../widgets/empty_screen.dart';

class CartScreen extends StatelessWidget {

  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {




    final Color color = Utils(context).color;
    Size size = Utils(context).getScreenSize;
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItemsList =
    cartProvider.getCartItems.values.toList().reversed.toList();
    return cartItemsList.isEmpty
        ? const EmptyScreen(
      title: 'Your cart is empty',
      subtitle: 'Add something and make me happy :)',
      buttonText: 'Shop now',
      imagePath: 'assets/images/cart.png',
    )
        : Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: TextWidget(
            text: 'Cart (${cartItemsList.length})',
            color: color,
            isTitle: true,
            textSize: 22,
          ),
          actions: [
            IconButton(
              onPressed: () {
                GlobalMethods.warningDialog(
                    title: 'Empty your cart?',
                    subtitle: 'Are you sure?',
                    fct: () async {
                      await cartProvider.clearOnlineCart();
                      cartProvider.clearLocalCart();
                    },
                    context: context);
              },
              icon: Icon(
                IconlyBroken.delete,
                color: color,
              ),
            ),
          ]),
      body: Column(
        children: [
          _checkout(ctx: context),
          Expanded(
            child: ListView.builder(
              itemCount: cartItemsList.length,
              itemBuilder: (ctx, index) {
                return ChangeNotifierProvider.value(
                    value: cartItemsList[index],
                    child: CartWidget(
                      q: cartItemsList[index].quantity,
                    ));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkout({required BuildContext ctx}) {
    Stripe.publishableKey =
    "pk_test_51NAYRLSE0rKEbAkdufaKYRhSOs8gNqCIb8YPxjXpy8FWFF2lVj00pzJOe5obiGMOSDtVSHIquYMcZMMo7LEZqEQR00sfUhLIHs";
    Map<String, dynamic>? paymentIntent;
    void makePayment() async {
      try {
        paymentIntent = await createPaymentIntent();

        var gpay = const PaymentSheetGooglePay(
          merchantCountryCode: "US",
          currencyCode: "USD",
          testEnv: true,
        );
        await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: paymentIntent!["client_secret"],
              style: ThemeMode.light,
              merchantDisplayName: "Sabir",
              googlePay: gpay,
            ));

        displayPaymentSheet();
      } catch (e) {
        print(e.toString());
      }
    }

    final Color color = Utils(ctx).color;
    Size size = Utils(ctx).getScreenSize;
    final cartProvider = Provider.of<CartProvider>(ctx);
    final productProvider = Provider.of<ProductsProvider>(ctx);
    final ordersProvider = Provider.of<OrdersProvider>(ctx);
    double total = 0.0;
    cartProvider.getCartItems.forEach((key, value) {
      final getCurrProduct = productProvider.findProdById(value.productId);
      total += (getCurrProduct.isOnSale
          ? getCurrProduct.salePrice
          : getCurrProduct.price) *
          value.quantity;
    });
    return SizedBox(
      width: double.infinity,
      height: size.height * 0.1,
      // color: ,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Material(
            color: Colors.green,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                makePayment();
                User? user = authInstance.currentUser;
                final orderId = const Uuid().v4();
                final productProvider =
                Provider.of<ProductsProvider>(ctx, listen: false);

                cartProvider.getCartItems.forEach((key, value) async {
                  final getCurrProduct = productProvider.findProdById(
                    value.productId,
                  );
                  try {
                    makePayment();
                    final orderId = const Uuid().v4();
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(orderId)
                        .set({
                      'orderId': orderId,
                      'userId': user!.uid,
                      'productId': value.productId,
                      'price': (getCurrProduct.isOnSale
                          ? getCurrProduct.salePrice
                          : getCurrProduct.price) *
                          value.quantity,
                      'totalPrice': total,
                      'quantity': value.quantity,
                      'imageUrl': getCurrProduct.imageUrl,
                      'userName': user.displayName,
                      'orderDate': Timestamp.now(),
                    }
                    );
                    await cartProvider.clearOnlineCart();
                    cartProvider.clearLocalCart();
                    ordersProvider.fetchOrders();
                    await Fluttertoast.showToast(
                      msg: "Your order has been placed",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.CENTER,
                    );
                  } catch (error) {
                    GlobalMethods.errorDialog(
                        subtitle: error.toString(), context: ctx);
                  } finally {}
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextWidget(
                  text: 'Order Now',
                  textSize: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const Spacer(),
          FittedBox(
            child: TextWidget(
              text: 'Total: \₹${total.toStringAsFixed(2)}',
              color: color,
              textSize: 18,
              isTitle: true,
            ),
          ),
        ]),
      ),
    );
  }
  void displayPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
      print("Done");
    } catch (e) {
      print("Failed");
    }
  }

  createPaymentIntent() async {
    try {
      Map<String, dynamic> body = {
        "amount": "10000",
        "currency": "USD",
      };

      http.Response response = await http.post(
          Uri.parse("https://api.stripe.com/v1/payment_intents"),
          body: body,
          headers: {
            "Authorization":
            "Bearer sk_test_51NAYRLSE0rKEbAkdcFt2ECrv3e5tP8NDmYKey8KzO0J7CKJEO0Wwi6tKgCpeSiBB4U1vdMcMEjYNC1tKIXvp9KOq00r7Nmv1k7",
            "Content-Type": "application/x-www-form-urlencoded",
          });
      return json.decode(response.body);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

}