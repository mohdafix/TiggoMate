import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class CheryServiceCentre {
  final String id;
  final String name;
  final String dealerName;
  final String type; // '4S' or '3S'
  final String region; // 'Klang Valley', 'Northern', 'Southern', 'East Coast', 'East Malaysia'
  final String state;
  final String address;
  final String phone;
  final String operatingHours;
  final bool hasBodyPaint;
  final bool isPhevCertified;

  const CheryServiceCentre({
    required this.id,
    required this.name,
    required this.dealerName,
    required this.type,
    required this.region,
    required this.state,
    required this.address,
    required this.phone,
    this.operatingHours = 'Mon - Sat: 8:30 AM - 5:30 PM • Sun: Closed',
    this.hasBodyPaint = false,
    this.isPhevCertified = true,
  });
}

class CheryServiceDirectory {
  static const String tollFreeCareline = '1800-88-2868';
  static const String dealerLocatorUrl = 'https://www.chery.my/dealer-locator/';

  static const List<CheryServiceCentre> centres = [
    // ---------------- KLANG VALLEY (KUALA LUMPUR & SELANGOR) ----------------
    CheryServiceCentre(
      id: 'kl_segambut',
      name: 'Chery Segambut',
      dealerName: 'Robust Marque Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Kuala Lumpur',
      address: 'Menara TKSS, 206, Jalan Segambut, Kawasan Perusahaan Segambut, 51200 Kuala Lumpur',
      phone: '03-89663708',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'kl_connaught',
      name: 'Chery Taman Connaught',
      dealerName: 'UCSI Auto Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Kuala Lumpur',
      address: 'No. A1-A6, B1-B3A, CMC Centre, Jalan Cerdas, Taman Connaught, 56000 Cheras, Kuala Lumpur',
      phone: '03-90782068',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'kl_sri_petaling',
      name: 'Chery Sri Petaling',
      dealerName: 'Ace Synergy Motor Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Kuala Lumpur',
      address: 'No. 18, Jalan Radin Bagus 3, Bandar Baru Sri Petaling, 57000 Kuala Lumpur',
      phone: '03-90553388',
      operatingHours: 'Mon - Sat: 9:00 AM - 6:00 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'sel_setia_alam',
      name: 'Chery Setia Alam',
      dealerName: 'Creater Auto Sdn. Bhd.',
      type: '4S',
      region: 'Klang Valley',
      state: 'Selangor',
      address: '1-4-G & 1-5-G Jalan Setia Prima WU13/W, Seksyen 13, Setia Alam, 40170 Shah Alam, Selangor',
      phone: '03-33459668',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: true,
    ),
    CheryServiceCentre(
      id: 'sel_puchong_bukit',
      name: 'Chery Bandar Bukit Puchong',
      dealerName: 'Lesydear Automobile Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Selangor',
      address: '2, Jalan BP 4, Bandar Bukit Puchong, 47120 Puchong, Selangor',
      phone: '1700-82-9956',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'sel_puchong_tpp',
      name: 'Chery Puchong TPP',
      dealerName: 'CNO Autohaus Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Selangor',
      address: 'Lot PT 197, No. 4, Jalan TPP 5/1, Taman Perindustrian Puchong, 47100 Puchong, Selangor',
      phone: '03-80608888',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: true,
    ),
    CheryServiceCentre(
      id: 'sel_klang_botanic',
      name: 'Chery Bandar Botanic Klang',
      dealerName: 'AI Futuretech Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Selangor',
      address: '1, Jalan Kasuarina 7, Bandar Botanic, 41200 Klang, Selangor',
      phone: '03-33182682',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'sel_balakong',
      name: 'Chery Balakong',
      dealerName: 'Tropical Impact Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Selangor',
      address: 'Lot 483, Block B-2, Jalan Balakong, Batu 11, 43200 Cheras, Selangor',
      phone: '03-23022968',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'sel_rawang',
      name: 'Chery Rawang',
      dealerName: 'Carro Care Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Selangor',
      address: 'Lot 15, Jalan Industri 3/1, Rawang Integrated Industrial Park, 48000 Rawang, Selangor',
      phone: '03-60921188',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'sel_bangi',
      name: 'Chery Bandar Baru Bangi 3S',
      dealerName: 'WH Oneplus Auto Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Selangor',
      address: 'No. 7 & 9, Jalan Perindustrian Suntrack, Hub Perindustrian Suntrack, Off Jalan P/1A, Seksyen 13, 43650 Bandar Baru Bangi, Selangor',
      phone: '03-89120907',
      operatingHours: 'Mon - Sat: 9:00 AM - 6:00 PM • Sun: Closed',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'sel_kd',
      name: 'Chery Kota Damansara 3S',
      dealerName: 'Apple Autotech Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Selangor',
      address: 'No. 29 & 31, Jalan PJU 5/20E, The Strand Kota Damansara, 47810 Petaling Jaya, Selangor',
      phone: '03-61428888',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'sel_semenyih',
      name: 'Chery Semenyih 3S',
      dealerName: 'G-Mart Motor Sdn. Bhd.',
      type: '3S',
      region: 'Klang Valley',
      state: 'Selangor',
      address: 'Lot 1826, Jalan Semenyih Sentral 1, 43500 Semenyih, Selangor',
      phone: '03-87278888',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),

    // ---------------- NORTHERN REGION ----------------
    CheryServiceCentre(
      id: 'png_butterworth',
      name: 'Chery Butterworth',
      dealerName: 'CS Euro Auto Sdn. Bhd.',
      type: '3S',
      region: 'Northern',
      state: 'Penang',
      address: '77, Tingkat Jalan Bagan Jermal, 12300 Butterworth, Penang',
      phone: '04-7330001',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'png_georgetown',
      name: 'Chery Georgetown',
      dealerName: 'BK Autoworld Sdn. Bhd.',
      type: '3S',
      region: 'Northern',
      state: 'Penang',
      address: '538, Jalan Dato Keramat, 10470 George Town, Pulau Pinang',
      phone: '04-2278877',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'prk_ipoh',
      name: 'Chery Ipoh',
      dealerName: 'Leading Fame Auto Sdn. Bhd.',
      type: '4S',
      region: 'Northern',
      state: 'Perak',
      address: 'No. 228, Jalan Sultan Iskandar / Jalan Lahat 4S Hub, 30000 Ipoh, Perak',
      phone: '05-2557188',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: true,
    ),
    CheryServiceCentre(
      id: 'prk_taiping',
      name: 'Chery Taiping',
      dealerName: 'Leading Fame Auto Sdn. Bhd.',
      type: '3S',
      region: 'Northern',
      state: 'Perak',
      address: 'Lot 342, Jalan Simpang, 34000 Taiping, Perak',
      phone: '05-8086688',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'kdh_alor_setar',
      name: 'Chery Alor Setar',
      dealerName: 'Indah Utara Enterprise Sdn. Bhd.',
      type: '3S',
      region: 'Northern',
      state: 'Kedah',
      address: 'Lot 304, Lorong Perak 16, Jalan Perusahaan Mergong 2, 05150 Alor Setar, Kedah',
      phone: '04-7308822',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'kdh_sp',
      name: 'Chery Sungai Petani',
      dealerName: 'CS Euro Auto Sdn. Bhd.',
      type: '3S',
      region: 'Northern',
      state: 'Kedah',
      address: 'Plot 48, Jalan Bakar Arang, Kawasan Perusahaan Bakar Arang, 08000 Sungai Petani, Kedah',
      phone: '04-4219999',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),

    // ---------------- SOUTHERN REGION ----------------
    CheryServiceCentre(
      id: 'ns_seremban',
      name: 'Chery Seremban',
      dealerName: 'Taycn Kredit Sdn. Bhd.',
      type: '4S',
      region: 'Southern',
      state: 'Negeri Sembilan',
      address: 'Lot 2413, Pekan Rahang Baru, Jalan Tampin, 70450 Seremban, Negeri Sembilan',
      phone: '06-6787760',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: true,
    ),
    CheryServiceCentre(
      id: 'mlk_cheng',
      name: 'Chery Melaka',
      dealerName: 'AJ Asia Auto Sdn. Bhd.',
      type: '3S',
      region: 'Southern',
      state: 'Melaka',
      address: '12, Jalan TTC 12A, Taman Teknologi Cheng, 75250 Melaka',
      phone: '016-7710323',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'jhr_tampoi',
      name: 'Chery Tampoi 4S',
      dealerName: 'Autohub Mobility Sdn. Bhd.',
      type: '4S',
      region: 'Southern',
      state: 'Johor',
      address: '125-3, Batu 4 ½, Jalan Skudai Kiri, Kampung Skudai Kiri, 81200 Johor Bahru, Johor',
      phone: '010-2067299',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: true,
    ),
    CheryServiceCentre(
      id: 'jhr_kulai',
      name: 'Chery Kulai 3S',
      dealerName: 'Autohub Mobility Sdn. Bhd.',
      type: '3S',
      region: 'Southern',
      state: 'Johor',
      address: 'No. 4, Jalan SME 1, Kawasan Perindustrian SME, Bandar Indahpura, 81000 Kulai, Johor',
      phone: '07-6608866',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'jhr_johor_jaya',
      name: 'Chery Johor Jaya',
      dealerName: 'Desa Jaya Auto Sdn. Bhd.',
      type: '3S',
      region: 'Southern',
      state: 'Johor',
      address: 'PTD 52709, Jalan Rosmerah, Taman Johor Jaya, 81100 Johor Bahru, Johor',
      phone: '07-3552288',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'jhr_batu_pahat',
      name: 'Chery Batu Pahat',
      dealerName: 'G-Mart Motor Sdn. Bhd.',
      type: '3S',
      region: 'Southern',
      state: 'Johor',
      address: 'No. 12, Jalan Tan Swee Hoe, Taman Tan Swee Hoe, 83000 Batu Pahat, Johor',
      phone: '07-4313322',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'jhr_muar',
      name: 'Chery Muar',
      dealerName: 'Autohub Mobility Sdn. Bhd.',
      type: '3S',
      region: 'Southern',
      state: 'Johor',
      address: 'Lot 2450, Jalan Salleh, 84000 Muar, Johor',
      phone: '06-9527788',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'ns_nilai',
      name: 'Chery Nilai 3S',
      dealerName: 'SS Mobile Sdn. Bhd.',
      type: '3S',
      region: 'Southern',
      state: 'Negeri Sembilan',
      address: 'Lot 13813, Jalan BBN 1/3E, Putra Nilai, 71800 Nilai, Negeri Sembilan',
      phone: '06-8501188',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'jhr_medini',
      name: 'Chery Medini 4S',
      dealerName: 'Gagner Auto Sdn. Bhd.',
      type: '4S',
      region: 'Southern',
      state: 'Johor',
      address: 'Medini 7, Jalan Medini Sentral 5, Bandar Medini Iskandar, 79250 Iskandar Puteri, Johor',
      phone: '07-5090188',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: true,
    ),
    CheryServiceCentre(
      id: 'jhr_kluang',
      name: 'Chery Kluang 3S',
      dealerName: 'Li Koon Auto Sdn. Bhd.',
      type: '3S',
      region: 'Southern',
      state: 'Johor',
      address: 'No. 2, Jalan Perdana 1/1, Taman Kluang Perdana, 86000 Kluang, Johor',
      phone: '07-7738888',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),

    // ---------------- EAST COAST ----------------
    CheryServiceCentre(
      id: 'phg_kuantan',
      name: 'Chery Kuantan',
      dealerName: 'EVenergy Auto Sdn. Bhd.',
      type: '4S',
      region: 'East Coast',
      state: 'Pahang',
      address: 'No. 6, Jalan Industri Semambu 2, Kawasan Perindustrian Semambu, 25350 Kuantan, Pahang',
      phone: '016-9345691',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: true,
    ),
    CheryServiceCentre(
      id: 'ktn_kota_bharu',
      name: 'Chery Kota Bharu',
      dealerName: 'Murni Cartrade Sdn. Bhd.',
      type: '3S',
      region: 'East Coast',
      state: 'Kelantan',
      address: 'Lot 915, Jalan Long Yunus, Off Jalan Bayam, 15200 Kota Bharu, Kelantan',
      phone: '09-7445588',
      operatingHours: 'Sun - Thu: 8:30 AM - 5:30 PM • Fri: Closed',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'trg_kt',
      name: 'Chery Kuala Terengganu',
      dealerName: 'Dua Puncak Auto Sdn. Bhd.',
      type: '3S',
      region: 'East Coast',
      state: 'Terengganu',
      address: 'Lot 5542, Jalan Sultan Mohamad, Gong Badak, 21300 Kuala Terengganu, Terengganu',
      phone: '09-6669988',
      operatingHours: 'Sun - Thu: 8:30 AM - 5:30 PM • Fri: Closed',
      hasBodyPaint: false,
    ),

    // ---------------- EAST MALAYSIA (SABAH & SARAWAK) ----------------
    CheryServiceCentre(
      id: 'sbh_kk',
      name: 'Chery Kota Kinabalu',
      dealerName: 'Universal Chery Sdn. Bhd.',
      type: '3S',
      region: 'East Malaysia',
      state: 'Sabah',
      address: 'Lot 7, Jalan Limau Manis, Off Jalan Lintas Inanam (Taman Iramanis), 88450 Kota Kinabalu, Sabah',
      phone: '088-388988',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: true,
    ),
    CheryServiceCentre(
      id: 'sbh_tawau',
      name: 'Chery Tawau',
      dealerName: 'Universal Chery Sdn. Bhd.',
      type: '3S',
      region: 'East Malaysia',
      state: 'Sabah',
      address: 'TB4005, Taman Berkeley, Batu 1, Jalan Apas, 91000 Tawau, Sabah',
      phone: '089-772266',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'sbh_sandakan',
      name: 'Chery Sandakan',
      dealerName: 'Universal Chery Sdn. Bhd.',
      type: '3S',
      region: 'East Malaysia',
      state: 'Sabah',
      address: 'Mile 4, North Road, Bandar Labuk Jaya, 90000 Sandakan, Sabah',
      phone: '089-218899',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'swk_kuching',
      name: 'Chery Kuching (Batu Kawa)',
      dealerName: 'HMBC Sdn. Bhd.',
      type: '3S',
      region: 'East Malaysia',
      state: 'Sarawak',
      address: 'Lot 467 & 468, Block 215, KNLD, Jalan Batu Kawa, 93250 Kuching, Sarawak',
      phone: '082-688888',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: true,
    ),
    CheryServiceCentre(
      id: 'swk_sibu',
      name: 'Chery Sibu',
      dealerName: 'HMBC Sdn. Bhd.',
      type: '3S',
      region: 'East Malaysia',
      state: 'Sarawak',
      address: 'No. 32, Jalan Lanang, 96000 Sibu, Sarawak',
      phone: '084-332288',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
    CheryServiceCentre(
      id: 'swk_miri',
      name: 'Chery Miri',
      dealerName: 'HMBC Sdn. Bhd.',
      type: '3S',
      region: 'East Malaysia',
      state: 'Sarawak',
      address: 'Lot 1824, Jalan Pujut 7, 98000 Miri, Sarawak',
      phone: '085-412288',
      operatingHours: 'Mon - Sat: 8:30 AM - 5:30 PM',
      hasBodyPaint: false,
    ),
  ];
}

class CheryServiceCentresScreen extends StatefulWidget {
  final bool isEmbedded;
  const CheryServiceCentresScreen({super.key, this.isEmbedded = false});

  @override
  State<CheryServiceCentresScreen> createState() => _CheryServiceCentresScreenState();
}

class _CheryServiceCentresScreenState extends State<CheryServiceCentresScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRegion = 'All';
  String _selectedType = 'All'; // 'All', '4S', '3S'

  final List<String> _regions = [
    'All',
    'Klang Valley',
    'Northern',
    'Southern',
    'East Coast',
    'East Malaysia',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri telUri = Uri.parse('tel:$cleanPhone');
    try {
      final launched = await launchUrl(telUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _copyToClipboard(phoneNumber, 'Phone number copied: $phoneNumber');
      }
    } catch (_) {
      _copyToClipboard(phoneNumber, 'Phone number copied: $phoneNumber');
    }
  }

  Future<void> _openMaps(String name, String address) async {
    final query = Uri.encodeComponent('$name, $address');
    final Uri geoUri = Uri.parse('geo:0,0?q=$query');
    final Uri webMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      bool launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        _copyToClipboard(address, 'Address copied: $address');
      }
    } catch (_) {
      try {
        final launched = await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
        if (!launched) {
          _copyToClipboard(address, 'Address copied: $address');
        }
      } catch (_) {
        _copyToClipboard(address, 'Address copied: $address');
      }
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF00D2AA),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = CheryServiceDirectory.centres.where((centre) {
      final matchesRegion = _selectedRegion == 'All' || centre.region == _selectedRegion;
      final matchesType = _selectedType == 'All' || centre.type == _selectedType;
      final matchesQuery = query.isEmpty ||
          centre.name.toLowerCase().contains(query) ||
          centre.dealerName.toLowerCase().contains(query) ||
          centre.state.toLowerCase().contains(query) ||
          centre.address.toLowerCase().contains(query);
      return matchesRegion && matchesType && matchesQuery;
    }).toList();

    Widget content = Column(
      children: [
        // 24/7 Roadside Assistance Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2A32), Color(0xFF131922)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D2AA).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent, color: Color(0xFF00D2AA), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Chery 24/7 Roadside Careline',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Toll-Free Nationwide • High Voltage PHEV Rescue',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(CheryServiceDirectory.tollFreeCareline),
                  icon: const Icon(Icons.call, size: 14, color: Colors.black87),
                  label: const Text('Call', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D2AA),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search city, dealer, or location (e.g. Puchong, Tampoi, Ipoh)...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Colors.white38),
              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF00D2AA)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF131922),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF232D3D)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF232D3D)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF00D2AA)),
              ),
            ),
          ),
        ),

        // Filter Chips (Regions & Types)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              ..._regions.map((reg) {
                final isSelected = _selectedRegion == reg;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(reg, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.black : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedRegion = reg),
                    backgroundColor: const Color(0xFF131922),
                    selectedColor: const Color(0xFF00D2AA),
                    side: BorderSide(color: isSelected ? const Color(0xFF00D2AA) : const Color(0xFF232D3D)),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // Type toggle (4S vs 3S)
              ...['All', '4S', '3S'].map((tp) {
                final isSelected = _selectedType == tp;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(tp == 'All' ? 'All Types' : '$tp Only', style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white60)),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedType = tp),
                    backgroundColor: const Color(0xFF131922),
                    selectedColor: const Color(0xFF2F81F7),
                    side: BorderSide(color: isSelected ? const Color(0xFF2F81F7) : const Color(0xFF232D3D)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  ),
                );
              }),
            ],
          ),
        ),

        // Count indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${filtered.length} authorised centres',
                style: const TextStyle(fontSize: 11.5, color: Colors.white54, fontWeight: FontWeight.w600),
              ),
              InkWell(
                onTap: () async {
                  final uri = Uri.parse(CheryServiceDirectory.dealerLocatorUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Row(
                  children: const [
                    Text('Official Portal', style: TextStyle(fontSize: 11, color: Color(0xFF00D2AA), fontWeight: FontWeight.bold)),
                    SizedBox(width: 2),
                    Icon(Icons.open_in_new, size: 12, color: Color(0xFF00D2AA)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Centre List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off_outlined, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text('No service centres found matching "$query"', style: const TextStyle(color: Colors.white54)),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _selectedRegion = 'All';
                            _selectedType = 'All';
                          });
                        },
                        child: const Text('Reset Filters', style: TextStyle(color: Color(0xFF00D2AA))),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final centre = filtered[index];
                    return _buildCentreCard(centre);
                  },
                ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chery Service Network', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
      ),
      body: content,
    );
  }

  Widget _buildCentreCard(CheryServiceCentre centre) {
    final is4S = centre.type == '4S';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Name, Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        centre.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        centre.dealerName,
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: is4S
                        ? const Color(0xFF2F81F7).withValues(alpha: 0.2)
                        : const Color(0xFF00D2AA).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: is4S
                          ? const Color(0xFF2F81F7).withValues(alpha: 0.6)
                          : const Color(0xFF00D2AA).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    centre.type,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: is4S ? const Color(0xFF58A6FF) : const Color(0xFF00D2AA),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Capabilities Pill Row
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildCapabilityBadge(Icons.bolt, 'PHEV / HV Diagnostic Ready', const Color(0xFF00D2AA)),
                if (centre.hasBodyPaint)
                  _buildCapabilityBadge(Icons.format_paint, 'Body & Paint (B&P)', const Color(0xFF2F81F7)),
                _buildCapabilityBadge(Icons.location_on_outlined, centre.state, Colors.white54),
              ],
            ),
            const SizedBox(height: 10),

            // Address Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place, size: 15, color: Colors.white38),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    centre.address,
                    style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Hours Row
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    centre.operatingHours,
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFF232D3D)),

            // Action Row
            Row(
              children: [
                // Phone display
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF00D2AA)),
                      const SizedBox(width: 6),
                      Text(
                        centre.phone,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Call Button
                OutlinedButton.icon(
                  onPressed: () => _makePhoneCall(centre.phone),
                  icon: const Icon(Icons.call, size: 13, color: Color(0xFF00D2AA)),
                  label: const Text('Call', style: TextStyle(fontSize: 11.5, color: Color(0xFF00D2AA), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00D2AA)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                // Navigate Button
                ElevatedButton.icon(
                  onPressed: () => _openMaps(centre.name, centre.address),
                  icon: const Icon(Icons.directions, size: 13, color: Colors.black87),
                  label: const Text('Map', style: TextStyle(fontSize: 11.5, color: Colors.black87, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D2AA),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
