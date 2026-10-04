import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/evm_rpc_service.dart';
import '../core/wallet/wallet_service.dart';
import '../theme/app_theme.dart';
import 'transaction_detail_screen.dart';

class ActivityScreen extends StatefulWidget { const ActivityScreen({super.key}); @override State<ActivityScreen> createState()=>_ActivityScreenState(); }
class _ActivityScreenState extends State<ActivityScreen>{
 final _wallet=WalletService(); final _rpc=EvmRpcService(); Timer? _timer; List<String> _hashes=const []; final Map<String,String> _statuses={}; bool _loading=true;
 @override void initState(){super.initState();_load();_timer=Timer.periodic(const Duration(seconds:8),(_)=>_refreshStatuses());}
 Future<void> _load() async{final h=await _wallet.getActivity();if(!mounted)return;setState((){_hashes=h;_loading=false;});await _refreshStatuses();}
 Future<void> _refreshStatuses() async{for(final h in _hashes){try{final r=await _rpc.getTransactionReceipt(h);final s=r==null?'Pending':(r['status']=='0x1'?'Confirmed':'Failed');if(mounted)setState(()=>_statuses[h]=s);}catch(_){if(mounted&&!_statuses.containsKey(h))setState(()=>_statuses[h]='Checking');}}}
 @override void dispose(){_timer?.cancel();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Activity')),body:RefreshIndicator(onRefresh:_load,child:_loading?const Center(child:CircularProgressIndicator()):_hashes.isEmpty?ListView(children:const[SizedBox(height:180),_EmptyActivity()]):ListView.separated(padding:const EdgeInsets.all(18),itemCount:_hashes.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(_,i)=>_TransactionTile(hash:_hashes[i],status:_statuses[_hashes[i]]??'Checking')})));
}
class _TransactionTile extends StatelessWidget{final String hash,status;const _TransactionTile({required this.hash,required this.status});@override Widget build(BuildContext context){final failed=status=='Failed';final confirmed=status=='Confirmed';final icon=failed?Icons.error_outline:confirmed?Icons.check_circle_outline:Icons.hourglass_top_rounded;return Card(child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8),leading:CircleAvatar(backgroundColor:AppColors.mist,child:Icon(icon,color:failed?Colors.redAccent:AppColors.forest)),title:Text(status,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Padding(padding:const EdgeInsets.only(top:5),child:Text(hash.substring(0,10)+'...'+hash.substring(hash.length-8),style:const TextStyle(fontSize:12))),trailing:const Icon(Icons.arrow_forward_ios_rounded,size:15),onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>TransactionDetailScreen(hash:hash)))));}}
class _EmptyActivity extends StatelessWidget{const _EmptyActivity();@override Widget build(BuildContext context)=>Center(child:Column(children:const[Icon(Icons.receipt_long_rounded,size:64,color:AppColors.forest),SizedBox(height:16),Text('No activity yet',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),SizedBox(height:6),Text('Your Sepolia transactions will appear here.',style:TextStyle(color:Colors.black54))]));}