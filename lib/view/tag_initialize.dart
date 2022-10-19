import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:app/utility/extensions.dart';
import 'package:app/view/common/form_row.dart';
import 'package:app/view/common/nfc_session.dart';
import 'package:app/view/ndef_record.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:provider/provider.dart';

Future createPost(String url, Map body) async {
  return http.post(Uri.parse(url), body: body).then((http.Response response) {
    final int statusCode = response.statusCode;
    print(statusCode);
    if (statusCode < 200 || statusCode > 400 || json == null) {
      throw new Exception("Error while fetching data");
    }
    return CheckTagPost.fromJson(json.decode(response.body));
  });
}

class CheckTagPost {
  // New Fields TBD 
  final String userId;
  final int id;

  // Current fields
  final String name;
  final String email;
  final String password;
  final String tag;
  final String tagData;
  final String device;


  CheckTagPost({required this.userId, required this.id, required this.name, required this.email, required this.password, required this.tag, required this.tagData, required this.device});

  factory CheckTagPost.fromJson(Map json) {
    return CheckTagPost(
      userId: json['userId'],
      id: json['id'],
      name: json['name'],
      email: json['email'],
      password: json['password'],
      tag: json['tag'],
      tagData: json['tagData'],
      device: json['device'],
    );
  }

  Map toMap() {
    var map = new Map();
    map["userId"] = userId;
    map["name"] = name;
    map["email"] = email;
    map["password"] = password;
    map["tag"] = tag;
    map["tagData"] = tagData;
    map["device"] = device;

    return map;
  }
}

class TagInsomniacModel with ChangeNotifier {
  NfcTag? tag;

  Map<String, dynamic>? additionalData;

  Future<String?> handleTag(NfcTag tag) async {
    this.tag = tag;
    additionalData = {};

    Object? tech;

    // todo: more additional data
    if (Platform.isIOS) {
      tech = FeliCa.from(tag);
      if (tech is FeliCa) {
        final polling = await tech.polling(
          systemCode: tech.currentSystemCode,
          requestCode: FeliCaPollingRequestCode.noRequest,
          timeSlot: FeliCaPollingTimeSlot.max1,
        );
        additionalData!['manufacturerParameter'] = polling.manufacturerParameter;
      }
    }

    notifyListeners();
    return '[Tag - Initialize] is completed.';
  }
}

class TagInsomniacInitializePage extends StatelessWidget {
  static Widget withDependency() => ChangeNotifierProvider<TagInsomniacModel>(
    create: (context) => TagInsomniacModel(),
    child: TagInsomniacInitializePage(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tag - Insomniac Initialize'),
      ),
      body: ListView(
        padding: EdgeInsets.all(2),
        children: [
          FormSection(
            children: [
              FormRow(
                title: Text('Start Session', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                onTap: () => startSession(
                  context: context,
                  handleTag: Provider.of<TagInsomniacModel>(context, listen: false).handleTag,
                ),
              ),
            ],
          ),
          // consider: Selector<Tuple<{TAG}, {ADDITIONAL_DATA}>>
          Consumer<TagInsomniacModel>(builder: (context, model, _) {
            final tag = model.tag;
            final additionalData = model.additionalData;
            if (tag != null && additionalData != null)
              return _TagInfo(tag, additionalData);
            return SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}

class _TagInfo extends StatelessWidget {
  _TagInfo(this.tag, this.additionalData);

  final NfcTag tag;
  static final BASE_URL = "http://zohii.com:8080/";
  static final CHECK_POST_URL = "initializeTag";

  final Map<String, dynamic> additionalData;

  @override
  Widget build(BuildContext context) {
    final tagWidgets = <Widget>[];
    final ndefWidgets = <Widget>[];
    final insomniacWidgets = <Widget>[];
    var tagId;
    final Future post;

    Object? tech;

    var tagData = "";
    if (Platform.isAndroid) {
      tagId = (
        NfcA.from(tag)?.identifier ??
        NfcB.from(tag)?.identifier ??
        NfcF.from(tag)?.identifier ??
        NfcV.from(tag)?.identifier ??
        Uint8List(0)
      ).toHexString();
    }
    
    if (Platform.isIOS) {
      tagId = MiFare.from(tag)?.identifier.toHexString();
    }

    tech = Ndef.from(tag);
    if (tech is Ndef) {
      final cachedMessage = tech.cachedMessage;
      if (cachedMessage != null)
        Iterable.generate(cachedMessage.records.length).forEach((i) {
          final record = cachedMessage.records[i];
          final info = NdefRecordInfo.fromNdef(record);
          tagData = info.subtitle;
          ndefWidgets.add(FormRow(
            title: Text('#$i ${info.title}'),
            subtitle: Text('${info.subtitle}'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => NdefRecordPage(i, record),
            )),
          ));
        });
    }
    // final tagData = NdefRecordInfo.fromNdef(Ndef.from(tag).cachedMessage.records[0]).title;
    insomniacWidgets.add(FormRow(title: Text('$tagId'),
          subtitle: Text('$tagData')));
    tagId = tagId.replaceAll(" ", "");
    CheckTagPost newPost = new CheckTagPost(userId: "123", id: 0, name: "Hisato", email: "aaa@gmail.com", password: "aaa", tag: tagId, tagData: tagData, device: "00:20");
    // Post newPost = new Post(userId: "123", id: 0, name: "HisatoTownBoi", title: "AAA", body: "Aaaa");
    final postResult = createPost(BASE_URL+CHECK_POST_URL, newPost.toMap());
                        
    return Column(
      children: [
        FormSection(
          header: Text('${tagId}'),
          children: insomniacWidgets,
        )
      ],
    );
  }
}