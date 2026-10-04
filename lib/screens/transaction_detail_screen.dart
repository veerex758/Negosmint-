import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/network/evm_rpc_service.dart';
import '../theme/app_theme.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String hash;
  const TransactionDetailScreen({super.key, required this.hash});
  @override State<TransactionDetailScreen> createState()=>_TransactionDetailScreenState();
}
class _TransactionDetailScreenState extends State<TransactionDetailScreen>{
 final _rpc=EvmRpcService(); Map<String,dynamic>? _tx,_receipt; int? _timestamp; bool _loading=true; Object? _error;
 @override void initState(){super.initState();_load();}
 Future<void> _load() async {try{final tx=await _rpc.getTransactionByHash(widget.hash);final receipt=await _rpc.getTransactionReceipt(widget.hash);int? time;final block=receipt?['blockNumber'];if(block is String&&block!='0x')time=await _rpc.getBlockTimestamp(block);if(mounted)setState((){_tx=tx;_receipt=receipt;_timestamp=time;_loading=false;});}catch(e){if(mounted)setState((){_error=e;_loading=false;});}}
 String _hex(dynamic v){if(v is! String||!v.startsWith('0x'))return '-';try{return BigInt.parse(v.substring(2),radix:16).toString();}catch(_){return '-';}}
 String _eth(dynamic v){if(v is! String||!v.startsWith('0x'))return '-';try{final w=BigInt.parse(v.substring(2),radix:16);final whole=w~/BigInt.from(1000000000000000000);final f=(w%BigInt.from(1000000000000000000)).toString().padLeft(18,'0').replaceFirst(RegExp(r'0+$'),'');return whole.toString()+'.'+(f.isEmpty?'0':f.substring(0,f.length>6?6:f.length))+' ETH';}catch(_){return '-';}}
 String _status()=>_receipt==null?'Pending':(_receipt!['status']=='0x1'?'Confirmed':'Failed');
 String _date(){if(_timestamp==null)return 'Pending confirmation';final d=DateTime.fromMillisecondsSinceEpoch(_timestamp!*1000).toLocal();return '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';}
 Future<void> _copy(String value) async {await Clipboard.setData(ClipboardData(text:value));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Transaction hash copied')));}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Transaction details')),body:_loading?const Center(child:CircularProgressIndicator()):_error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Text('Unable to load transaction.\n'+_error.toString(),textAlign:TextAlign.center))):ListView(padding:const EdgeInsets.all(20),children:[
 Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:AppColors.mist,borderRadius:BorderRadius.circular(24)),child:Column(children:[Icon(_status()=='Confirmed'?Icons.check_circle_rounded:_status()=='Failed'?Icons.error_rounded:Icons.hourglass_top_rounded,color:AppColors.forest,size:46),const SizedBox(height:10),Text(_status(),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(_date(),style:const TextStyle(color:Colors.black54)),const SizedBox(height:4),const Text('Sepolia testnet',style:TextStyle(color:Colors.black54))])),
 const SizedBox(height:18),Card(child:Column(children:[_row('Amount',_eth(_tx?['value'])),_row('From',_tx?['from']?.toString()??'-'),_row('To',_tx?['to']?.toString()??'-'),_row('Nonce',_hex(_tx?['nonce'])),_row('Gas limit',_hex(_tx?['gas'])),_row('Gas used',_receipt==null?'-':_hex(_receipt!['gasUsed'])),_row('Block',_receipt==null?'Pending':_hex(_receipt!['blockNumber']))])),
 const SizedBox(height:18),Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Transaction hash',style:TextStyle(fontWeight:FontWeight.w800)),IconButton(onPressed:()=>_copy(widget.hash),icon:const Icon(Icons.copy_rounded)),const SizedBox(height:8),SelectableText(widget.hash,style:const TextStyle(fontSize:12))])))
 ]);
 Widget _row(String l,String v)=>Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:90,child:Text(l,style:const TextStyle(color:Colors.black54))),Expanded(child:SelectableText(v,textAlign:TextAlign.right,style:const TextStyle(fontWeight:FontWeight.w700)))]));
}