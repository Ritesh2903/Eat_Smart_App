import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:grocery/consts/firbase_consts.dart';

import '../services/global_methods.dart';
import '../services/utils.dart';

class HeartBTN extends StatelessWidget {
  const HeartBTN({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color color = Utils(context).color;
    return GestureDetector(
      onTap: () {
        final User? user = authInstance.currentUser;
        if(user==null){
          GlobalMethods.errorDialog(subtitle: 'No user found, Please login first', context: context);
          return;
        }
        print('print heart button is pressed');
      },
      child: Icon(
        IconlyLight.heart,
        size: 22,
        color: color,
      ),
    );
  }
}
