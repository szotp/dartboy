import 'package:flutter/cupertino.dart';

class Modal {
  /// Show a alert modal
  ///
  /// The onCancel callbacks receive BuildContext context as argument.
  static void alert(BuildContext context, String title, String message, {required Function onCancel}) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: new Text(title),
          actions: [
            new CupertinoDialogAction(
              child: new Text('OK'),
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                onCancel();
              },
            ),
          ],
          content: new Text(message),
        );
      },
    );
  }
}
