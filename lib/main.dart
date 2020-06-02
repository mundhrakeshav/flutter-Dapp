import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final String rpcUrl = 'http://192.168.225.244:7545';
  final String wsUrl = 'ws://192.168.225.244:7545/';
  //Do not use localhost because apk is installed in phone.localhost can be used if you
  // are listening locally.
  //
  //Left Blank Intentionally
  //
  //
  EthereumAddress contractAddress;
  //EthereumAddress of your contract. Has be initialized in loadData() function.
  //
  EthPrivateKey privateKey;
  //Private key of the user from whom transaction should be happening.
  //
  EthereumAddress recieverAddress =
      EthereumAddress.fromHex("0xe02101155fab8CbFA76e90494F7de3AE7151bef6");
  //Ethereum Address of reciever.
  //
  @override
  void initState() {
    loadData();
    super.initState();
  }

  loadData() async {
    //
    String abiStringFile = await rootBundle.loadString("src/abis/Coin.json");
    // Scans the complete data from json file created by truffle as a String.
    //
    final client = Web3Client(rpcUrl, Client(), socketConnector: () {
      return IOWebSocketChannel.connect(wsUrl).cast<String>();
    });
    //Creates web3Client for talking to port/Ganache.
    //
    var jsonAbi = jsonDecode(abiStringFile);
    //Decodes JsonFile and converted it to List
    //
    String abiCode = json.encode(jsonAbi["abi"]);
    //Extracts abi from json.
    //
    privateKey = EthPrivateKey.fromHex(
        "92cfb8692e440a6b55f2cddcebf348b23bdd510df0a0ad5f0ca6afeffc06e30d");
    //Address key of first user in ganache.
    //
    Credentials credentials = await client.credentialsFromPrivateKey(
        "92cfb8692e440a6b55f2cddcebf348b23bdd510df0a0ad5f0ca6afeffc06e30d");
    //Extracts credentials from Private key;
    //
    EthereumAddress ownAddress = await credentials.extractAddress();
    //Extracts address from credentials.
    //
    contractAddress =
        EthereumAddress.fromHex(jsonAbi["networks"]["5777"]["address"]);
    //Initalizes contracts Address using json file created by truffle.
    //
    DeployedContract contract = DeployedContract(
        ContractAbi.fromJson(abiCode, "Coin"), contractAddress);
    //Returns a intance of deployed contract
    //
    ContractEvent transferEvent = contract.event('Transfer');
    ContractFunction balanceFunction = contract.function('getBalance');
    ContractFunction sendFunction = contract.function('sendCoin');
    //Initilized all the the function and events and assigns them to variable
    //
    final subscription = client
        .events(FilterOptions.events(contract: contract, event: transferEvent))
        .take(1)
        .listen((event) {
      final decoded = transferEvent.decodeResults(event.topics, event.data);

      final from = decoded[0] as EthereumAddress;
      final to = decoded[1] as EthereumAddress;
      final value = decoded[2] as BigInt;

      print('$from sent $value MetaCoins to $to');
    });
    //Subscribed to events emmited by contract.
    //
    var balance = await client.call(
        contract: contract, function: balanceFunction, params: [ownAddress]);
    //call to the balance function of contract params are the parameters of contractFunction.
    //
    print('We have ${balance[0]} Coins');
    //balance is reaturned as a list so retriving its first value
    //
    await client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: sendFunction,
        parameters: [recieverAddress, balance.first],
      ),
    );
    //Sending a transaction to invoke contract and transfer all coins to reciever
    //
    balance = await client.call(
        contract: contract, function: balanceFunction, params: [ownAddress]);
    //Calls balance function again

    print('We have ${balance.first} Coins');
    // retrives value of coins to be 0.
    //
    client.sendTransaction(
        credentials,
        Transaction(
            from: ownAddress,
            to: recieverAddress,
            value: EtherAmount.inWei(BigInt.from(8000000000000000000))));
    // Sends ether to recieverAddress exactly 8 ether  = 8000000000000000000 wei
    //
    //Disposing resources
    await subscription.asFuture();
    await subscription.cancel();
    await client.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("widget.title"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: null,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
