import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_manage_accounts.dart';
import 'admin_organization_detail_screen.dart';
import 'admin_profile_screen.dart';
import '../auth/unified_login_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const green = Color(0xFF16A34A), darkGreen = Color(0xFF166534), bg = Color(0xFFF3FAF5);
  final db = Supabase.instance.client;
  int tab = 0;
  bool loading = true;
  List<Map<String,dynamic>> orgs = [], proposals = [], homeEvents = [];
  int members=0, events=0, users=0;
  Map<String,double> scores={};
  Map<String,int> orgMembers={}, orgEvents={}, orgProposals={}, orgComments={};

  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    if(mounted)setState(()=>loading=true);
    try {
      final o = await db.from('organizations').select('*').order('name');
      final m = await db.from('members').select('id,org_id,org_name');
      final e = await db.from('events').select('*').order('date', ascending:true);
      final p = await db.from('profiles').select('id,role');
      final pr = await db.from('event_requests').select('id,org_id,status,title,description,created_at').order('created_at',ascending:false);
      List<dynamic> comments=[];
      try { comments = await db.from('event_comments').select('event_id'); } catch(_){ }
      orgs=(o as List).map((x)=>Map<String,dynamic>.from(x)).toList();
      members=(m as List).length; events=(e as List).length; users=(p as List).length;
      orgMembers={}; orgEvents={}; orgProposals={}; orgComments={};
      for(final x in m as List){final id=x['org_id']?.toString()??''; if(id.isNotEmpty)orgMembers[id]=(orgMembers[id]??0)+1;}
      for(final x in e as List){final id=x['org_id']?.toString()??''; if(id.isNotEmpty)orgEvents[id]=(orgEvents[id]??0)+1;}
      for(final x in pr as List){final id=x['org_id']?.toString()??''; if(id.isNotEmpty)orgProposals[id]=(orgProposals[id]??0)+1;}
      for(final x in comments){ final eventId=x['event_id']?.toString(); final ev=(e as List).cast<Map>().where((r)=>r['id']?.toString()==eventId); if(ev.isNotEmpty){final id=ev.first['org_id']?.toString()??''; orgComments[id]=(orgComments[id]??0)+1;} }
      scores={for(final o in orgs) (o['id']?.toString()??''): ((orgMembers[o['id']?.toString()??'']??0) + (orgEvents[o['id']?.toString()??'']??0)*3 + (orgProposals[o['id']?.toString()??'']??0)*2 + (orgComments[o['id']?.toString()??'']??0)).toDouble()};
      proposals=(pr as List).where((x)=>x['status']=='forwarded_to_admin').map((x)=>Map<String,dynamic>.from(x)).toList();
      final now = DateTime.now();
      homeEvents = (e as List).where((x) {
        final d = DateTime.tryParse(x['date']?.toString() ?? '');
        return d == null || !d.isBefore(now);
      }).take(6).map((x)=>Map<String,dynamic>.from(x)).toList();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not load admin data: $e')));}
    if(mounted)setState(()=>loading=false);
  }
  Future<void> _logout() async { final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Log out?'),content:const Text('Sign out of the Admin / CSO account?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(style:FilledButton.styleFrom(backgroundColor:green),onPressed:()=>Navigator.pop(c,true),child:const Text('Log out'))])); if(yes!=true)return; await db.auth.signOut(); if(!mounted)return; Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const UnifiedLoginPage()),(_)=>false); }
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor:bg, body:SafeArea(child:loading?const Center(child:CircularProgressIndicator()):IndexedStack(index:tab,children:[_home(),_proposals(),_analytics(),_organizations(),const AdminProfileScreen()])), bottomNavigationBar:_nav());
  }
  Widget _nav()=>NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),backgroundColor:Colors.white,indicatorColor:green.withOpacity(.13),elevation:10,destinations:const[
    NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard_rounded,color:green),label:'Home'),
    NavigationDestination(icon:Icon(Icons.assignment_outlined),selectedIcon:Icon(Icons.assignment_rounded,color:green),label:'Proposals'),
    NavigationDestination(icon:Icon(Icons.insights_outlined),selectedIcon:Icon(Icons.insights_rounded,color:green),label:'Analytics'),
    NavigationDestination(icon:Icon(Icons.apartment_outlined),selectedIcon:Icon(Icons.apartment_rounded,color:green),label:'Organizations'),
    NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person_rounded,color:green),label:'Profile'),
  ]);
  Widget _top(String title, String subtitle, {List<Widget> actions = const []}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFDDEDE2)))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F3D23))),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ])),
        ...actions,
      ]),
    );
  }
  Widget _home()=>RefreshIndicator(onRefresh:_load,child:ListView(padding:EdgeInsets.zero,children:[_top('Admin / CSO','Organization management at a glance',actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh_rounded,color:green)),IconButton(onPressed:_logout,icon:const Icon(Icons.logout_rounded,color:green))]),Padding(padding:const EdgeInsets.all(18),child:Column(children:[_hero(),const SizedBox(height:16),_stats(),const SizedBox(height:18),_upcomingEvents(),const SizedBox(height:18),_quick(),const SizedBox(height:18),_pendingPreview()]))]));
  Widget _hero()=>Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[darkGreen,green]),borderRadius:BorderRadius.circular(28),boxShadow:[BoxShadow(color:green.withOpacity(.2),blurRadius:20,offset:Offset(0,8))]),child:Row(children:[Container(width:58,height:58,decoration:BoxDecoration(color:Colors.white.withOpacity(.14),borderRadius:BorderRadius.circular(18)),child:const Icon(Icons.admin_panel_settings_rounded,color:Colors.white,size:30)),const SizedBox(width:15),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Welcome, Admin 👋',style:TextStyle(color:Colors.white70,fontWeight:FontWeight.w600)),SizedBox(height:4),Text('Keep every organization on track.',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),SizedBox(height:5),Text('Review proposals, monitor activity, and keep financial reports ready.',style:TextStyle(color:Colors.white70,height:1.3))]))]));
  Widget _stats()=>GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:1.65,children:[_stat('Organizations',orgs.length,Icons.apartment_rounded),_stat('User Accounts',users,Icons.manage_accounts_rounded)]);

  Widget _upcomingEvents()=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:const Color(0xFFDDEDE2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.event_rounded,color:green),SizedBox(width:8),Text('Upcoming Events',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900))]),const SizedBox(height:12),if(homeEvents.isEmpty)const Text('No upcoming events posted yet.',style:TextStyle(color:Color(0xFF64748B))) else SizedBox(height:190,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:homeEvents.length,separatorBuilder:(_,__)=>const SizedBox(width:12),itemBuilder:(_,i){final e=homeEvents[i];final imgs=(e['image_urls'] is List?e['image_urls']:<dynamic>[]).whereType<String>().toList();final one=e['image_url']?.toString();if(one!=null&&one.isNotEmpty&&!imgs.contains(one))imgs.insert(0,one);return Container(width:230,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:const Color(0xFFF3FAF5),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFDDEDE2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:imgs.isNotEmpty?Image.network(imgs.first,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>_eventPlaceholder()):_eventPlaceholder()),Padding(padding:const EdgeInsets.all(11),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e['title']?.toString()??'Event',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,color:darkGreen)),const SizedBox(height:3),Text(e['org_name']?.toString()??'Organization',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:Color(0xFF64748B))) ]))]));}))]));
  Widget _eventPlaceholder()=>Container(color:green.withOpacity(.08),child:const Center(child:Icon(Icons.image_outlined,color:green,size:40)));
  Widget _stat(String l,int v,IconData i)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFFDDEDE2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:green.withOpacity(.10),borderRadius:BorderRadius.circular(12)),child:Icon(i,color:green)),const Spacer(),Text('$v',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:darkGreen)),Text(l,style:const TextStyle(color:Color(0xFF64748B),fontSize:12))]));
  Widget _quick()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Quick access',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:10),Row(children:[Expanded(child:_quickButton(Icons.assignment_rounded,'Review Proposals',()=>setState(()=>tab=1))),const SizedBox(width:10),Expanded(child:_quickButton(Icons.insights_rounded,'View Analytics',()=>setState(()=>tab=2)))]),const SizedBox(height:10),Row(children:[Expanded(child:_quickButton(Icons.apartment_rounded,'Organizations',()=>setState(()=>tab=3))),const SizedBox(width:10),Expanded(child:_quickButton(Icons.manage_accounts_rounded,'Accounts',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AdminAccountsScreen()))))])]);
  Widget _quickButton(IconData i,String t,VoidCallback tap)=>InkWell(onTap:tap,borderRadius:BorderRadius.circular(18),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFDDEDE2))),child:Row(children:[Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:green.withOpacity(.10),borderRadius:BorderRadius.circular(11)),child:Icon(i,color:green,size:20)),const SizedBox(width:10),Expanded(child:Text(t,style:const TextStyle(fontWeight:FontWeight.w800))),const Icon(Icons.chevron_right_rounded,color:Color(0xFF94A3B8))])));
  Widget _pendingPreview()=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:const Color(0xFFDDEDE2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Expanded(child:Text('Pending adviser proposals',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900))),_badge('${proposals.length}')]),const SizedBox(height:10),if(proposals.isEmpty)const Text('No proposals are waiting for CSO review.',style:TextStyle(color:Color(0xFF64748B))) else ...proposals.take(3).map((p)=>ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(backgroundColor:Color(0xFFE8F7ED),child:Icon(Icons.description_outlined,color:green)),title:Text(p['title']?.toString()??'Proposal',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('Organization ${p['org_id']??''}'),trailing:const Icon(Icons.chevron_right_rounded)))]));
  Widget _proposals()=>RefreshIndicator(onRefresh:_load,child:ListView(padding:EdgeInsets.zero,children:[_top('Activity Proposals','Advisers send proposed activities here for CSO approval',actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh_rounded,color:green))]),Padding(padding:const EdgeInsets.all(18),child:Column(children:[_proposalGuide(),const SizedBox(height:14),if(proposals.isEmpty)_empty('No proposals waiting for approval.',Icons.inbox_outlined) else ...proposals.map(_proposalCard)]))]));
  Widget _proposalGuide()=>Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:const Color(0xFFE8F7ED),borderRadius:BorderRadius.circular(20)),child:const Row(children:[Icon(Icons.route_rounded,color:darkGreen),SizedBox(width:12),Expanded(child:Text('Adviser → Admin / CSO → Adviser → Officers → Final creative → Adviser → Publish',style:TextStyle(color:darkGreen,fontWeight:FontWeight.w800,height:1.35)))]));
  Widget _proposalCard(Map<String,dynamic> p)=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFFDDEDE2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:green.withOpacity(.1),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.assignment_outlined,color:green)),const SizedBox(width:12),Expanded(child:Text(p['title']?.toString()??'Untitled proposal',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))),_badge('Awaiting CSO')]),const SizedBox(height:10),Text(p['description']?.toString()??'No description.',style:const TextStyle(color:Color(0xFF64748B),height:1.4)),const SizedBox(height:12),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>_review(p,false),icon:const Icon(Icons.undo_rounded),label:const Text('Return to Adviser'))),const SizedBox(width:8),Expanded(child:FilledButton.icon(style:ButtonStyle(backgroundColor:const MaterialStatePropertyAll(green)),onPressed:()=>_review(p,true),icon:const Icon(Icons.check_circle_outline),label:const Text('Approve')))])]));
  Future<void> _review(Map<String,dynamic> p,bool approve) async {final c=TextEditingController();if(!approve){final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(title:const Text('Return to Adviser'),content:TextField(controller:c,maxLines:4,decoration:const InputDecoration(labelText:'What needs improvement?',hintText:'Give clear feedback for the adviser.',border:OutlineInputBorder())),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(style:ButtonStyle(backgroundColor:const MaterialStatePropertyAll(green)),onPressed:()=>Navigator.pop(x,true),child:const Text('Return'))]));if(ok!=true){c.dispose();return;}}try{await db.from('event_requests').update({'status':approve?'admin_approved':'admin_rejected','admin_feedback':c.text.trim(),'admin_reviewed_at':DateTime.now().toIso8601String(),'reviewed_by':db.auth.currentUser?.id}).eq('id',p['id']);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(approve?'Proposal approved.':'Proposal returned to adviser.'),backgroundColor:green));await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not update proposal: $e')));}c.dispose();}
  Widget _analytics()=>RefreshIndicator(onRefresh:_load,child:ListView(padding:EdgeInsets.zero,children:[_top('Analytics','Organization activity, participation, and reports',actions:[IconButton(onPressed:_printAnalytics,icon:const Icon(Icons.print_rounded,color:green)),IconButton(onPressed:_load,icon:const Icon(Icons.refresh_rounded,color:green))]),Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_activityHero(),const SizedBox(height:16),_activityList(active:true),const SizedBox(height:16),_activityList(active:false),const SizedBox(height:16),_reportCard()]))]));
  Widget _activityHero()=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[darkGreen,green]),borderRadius:BorderRadius.circular(24)),child:Row(children:[const Icon(Icons.insights_rounded,color:Colors.white,size:40),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Organization Activity',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('Activity score = members + events × 3 + proposals × 2 + comments.',style:TextStyle(color:Colors.white70,fontSize:12,height:1.35))]))]));
  List<Map<String,dynamic>> _ranked(){final list=orgs.map((o){final id=o['id']?.toString()??'';return {'org':o,'score':scores[id]??0.0,'members':orgMembers[id]??0,'events':orgEvents[id]??0,'proposals':orgProposals[id]??0};}).toList();list.sort((a,b)=>(b['score'] as double).compareTo(a['score'] as double));return list;}
  Widget _activityList({required bool active}) {
    final ranked = _ranked();
    final rows = active ? ranked.take(5).toList() : ranked.reversed.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(active ? 'Most Active Organizations' : 'Organizations Needing Attention', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        if (ranked.isEmpty)
          _empty('No organizations found.', Icons.apartment_outlined)
        else
          ...rows.map((x) {
            final org = x['org'] as Map<String, dynamic>;
            return InkWell(
              onTap: () => _openOrg(org),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFDDEDE2))),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: const Color(0xFFE8F7ED), child: Text('${ranked.indexOf(x) + 1}', style: const TextStyle(color: darkGreen, fontWeight: FontWeight.w900))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(org['name']?.toString() ?? 'Organization', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${x['members']} members • ${x['events']} events • ${x['proposals']} proposals', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: active ? const Color(0xFFE8F7ED) : const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(20)),
                      child: Text('${(x['score'] as double).round()} pts', style: TextStyle(color: active ? darkGreen : Colors.orange.shade800, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
  Widget _reportCard()=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFFDDEDE2))),child:Row(children:[Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:green.withOpacity(.1),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.print_rounded,color:green)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Admin Reports',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16)),SizedBox(height:3),Text('Print the current organization analytics when needed.',style:TextStyle(color:Color(0xFF64748B),fontSize:12))])),FilledButton.icon(style:ButtonStyle(backgroundColor:const MaterialStatePropertyAll(green)),onPressed:_printAnalytics,icon:const Icon(Icons.print),label:const Text('Print'))]));
  Future<void> _printAnalytics() async {final r=_ranked();final doc=pw.Document();doc.addPage(pw.MultiPage(build:(_)=>[pw.Header(level:0,child:pw.Text('OrgConnect Analytics')),pw.Text('Organization activity report'),pw.SizedBox(height:12),...r.map((x)=>pw.Text('${x['org']['name']} — ${x['score'].round()} points | ${x['members']} members | ${x['events']} events | ${x['proposals']} proposals'))]));await Printing.layoutPdf(onLayout:(_)=>doc.save());}
  Widget _organizations()=>RefreshIndicator(onRefresh:_load,child:ListView(padding:EdgeInsets.zero,children:[_top('Organizations','Open an organization to see its complete report',actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh_rounded,color:green))]),Padding(padding:const EdgeInsets.all(18),child:Column(children:[if(orgs.isEmpty)_empty('No organizations found.',Icons.apartment_outlined),...orgs.map((o)=>_orgCard(o))]))]));
  Widget _orgCard(Map<String, dynamic> o) {
    final id = o['id']?.toString() ?? '';
    final logo = o['logo_asset']?.toString() ?? '';
    return InkWell(
      onTap: () => _openOrg(o),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFDDEDE2))),
        child: Row(
          children: [
            Container(width:56,height:56,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:const Color(0xFFE8F7ED),borderRadius:BorderRadius.circular(16)),child: logo.startsWith('http') ? Image.network(logo,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.groups_rounded,color:green)) : logo.isNotEmpty ? Image.asset(logo.startsWith('assets/') ? logo : 'assets/$logo',fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.groups_rounded,color:green)) : const Icon(Icons.groups_rounded,color:green)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o['name']?.toString() ?? 'Organization', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${orgMembers[id] ?? 0} members • ${orgEvents[id] ?? 0} events', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 8),
              Text(o['short_desc']?.toString() ?? 'Open to view officers, proposals, events, and liquidation.', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
  void _openOrg(Map<String,dynamic> o){Navigator.push(context,MaterialPageRoute(builder:(_)=>AdminOrganizationDetailScreen(orgId:o['id'].toString(),orgName:o['name']?.toString()??'Organization')));}
  Widget _badge(String t)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:green.withOpacity(.1),borderRadius:BorderRadius.circular(30)),child:Text(t,style:const TextStyle(color:darkGreen,fontSize:11,fontWeight:FontWeight.w800)));
  Widget _empty(String t,IconData i)=>Container(padding:const EdgeInsets.all(30),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFFDDEDE2))),child:Column(children:[Icon(i,size:48,color:green),const SizedBox(height:12),Text(t,textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFF64748B),fontWeight:FontWeight.w600))]));
}
