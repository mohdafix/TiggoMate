import 'package:geolocator/geolocator.dart';
import '../theme/app_tokens.dart';
import 'book_service_appointment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../trips/smart_trip_tracker.dart';
import 'app_notification.dart';
import 'book_service_appointment_sheet.dart';

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
  final double latitude;
  final double longitude;

  const CheryServiceCentre({
    required this.id,
    required this.name,
    required this.dealerName,
    required this.type,
    required this.region,
    required this.state,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
    this.operatingHours = 'Mon - Sat: 8:30 AM - 5:30 PM • Sun: Closed',
    this.hasBodyPaint = false,
    this.isPhevCertified = true,
  });

  /// Calculates geodesic distance to user location in kilometers
  double distanceTo(double userLat, double userLng) {
    return Geolocator.distanceBetween(userLat, userLng, latitude, longitude) / 1000.0;
  }
}

class CheryServiceDirectory {
  static const String tollFreeCareline = '1800-88-2868';
  static const String dealerLocatorUrl = 'https://www.chery.my/dealer-locator/';

  static const List<CheryServiceCentre> centres = [
    // ---------------- KLANG VALLEY (KUALA LUMPUR & SELANGOR) ----------------
    CheryServiceCentre(
      id: 'kl_segambut',
      latitude: 3.1872,
      longitude: 101.6705,
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
      latitude: 3.0827,
      longitude: 101.7378,
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
      latitude: 3.0673,
      longitude: 101.6917,
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
      latitude: 3.1118,
      longitude: 101.4496,
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
      latitude: 2.9865,
      longitude: 101.6212,
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
      latitude: 3.0182,
      longitude: 101.6115,
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
      latitude: 2.9972,
      longitude: 101.4398,
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
      latitude: 3.0315,
      longitude: 101.7642,
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
      latitude: 3.3082,
      longitude: 101.5458,
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
      latitude: 2.9463,
      longitude: 101.7765,
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
      latitude: 3.1534,
      longitude: 101.5942,
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
      latitude: 2.9515,
      longitude: 101.8441,
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
      latitude: 5.4295,
      longitude: 100.3845,
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
      latitude: 5.4124,
      longitude: 100.3185,
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
      latitude: 4.5821,
      longitude: 101.0742,
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
      latitude: 4.8295,
      longitude: 100.7185,
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
      latitude: 6.1365,
      longitude: 100.3541,
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
      latitude: 5.6272,
      longitude: 100.4875,
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
      latitude: 2.6954,
      longitude: 101.9562,
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
      latitude: 2.2612,
      longitude: 102.2185,
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
      latitude: 1.5034,
      longitude: 103.7042,
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
      latitude: 1.6425,
      longitude: 103.6128,
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
      latitude: 1.5432,
      longitude: 103.8012,
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
      latitude: 1.8542,
      longitude: 102.9456,
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
      latitude: 2.0512,
      longitude: 102.5845,
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
      latitude: 2.8125,
      longitude: 101.7954,
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
      latitude: 1.4285,
      longitude: 103.6312,
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
      latitude: 2.0345,
      longitude: 103.2985,
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
      latitude: 3.8452,
      longitude: 103.3215,
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
      latitude: 6.1154,
      longitude: 102.2542,
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
      latitude: 5.3854,
      longitude: 103.0945,
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
      latitude: 5.9685,
      longitude: 116.1125,
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
      latitude: 4.2542,
      longitude: 117.8965,
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
      latitude: 5.8642,
      longitude: 118.0625,
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
      latitude: 1.5125,
      longitude: 110.3154,
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
      latitude: 2.2845,
      longitude: 111.8312,
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
      latitude: 4.4325,
      longitude: 114.0152,
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
  bool _sortByNearest = false;
  Position? _userPosition;
  bool _isLocatingGps = false;

  final List<String> _regions = [
    'All',
    'Klang Valley',
    'Northern',
    'Southern',
    'East Coast',
    'East Malaysia',
  ];

  @override
  void initState() {
    super.initState();
    _attemptSilentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Attempts silent check for active GPS coordinates from SmartTripTracker or device GNSS
  Future<void> _attemptSilentLocation() async {
    try {
      final tracker = SmartTripTracker.instance;
      if (tracker.breadcrumbs.isNotEmpty) {
        final last = tracker.breadcrumbs.last;
        if (last.latitude != null && last.longitude != null) {
          if (mounted) {
            setState(() {
              _userPosition = Position(
                latitude: last.latitude!,
                longitude: last.longitude!,
                timestamp: DateTime.now(),
                accuracy: 10,
                altitude: 0,
                altitudeAccuracy: 0,
                heading: 0,
                headingAccuracy: 0,
                speed: 0,
                speedAccuracy: 0,
              );
              _sortByNearest = true;
            });
          }
          return;
        }
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 4)),
        );
        if (mounted) {
          setState(() {
            _userPosition = pos;
            _sortByNearest = true;
          });
        }
      }
    } catch (_) {}
  }

  /// Interactive request to enable GPS sorting and acquire fix
  Future<void> _requestGpsSort() async {
    setState(() {
      _isLocatingGps = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _isLocatingGps = false);
          AppNotification.show(
            context,
            title: 'GPS Service Disabled',
            message: 'Please turn on Location Services on your phone to find nearby centres.',
            type: NotificationType.warning,
            icon: Icons.location_off,
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() => _isLocatingGps = false);
            AppNotification.show(
              context,
              title: 'Permission Denied',
              message: 'Location access is needed to sort Chery service centres by distance.',
              type: NotificationType.warning,
              icon: Icons.location_off,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isLocatingGps = false);
          AppNotification.show(
            context,
            title: 'Permission Blocked',
            message: 'Please enable Location in Android Settings for TiggoMate.',
            type: NotificationType.warning,
            icon: Icons.settings,
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );

      if (mounted) {
        setState(() {
          _userPosition = pos;
          _sortByNearest = true;
          _isLocatingGps = false;
        });

        AppNotification.show(
          context,
          title: 'Nearby GPS Active',
          message: 'Showing authorised Chery service centres ordered by closest driving distance.',
          type: NotificationType.success,
          icon: Icons.near_me_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocatingGps = false);
        AppNotification.show(
          context,
          title: 'Location Fix Timeout',
          message: 'Could not obtain GPS lock indoors. Showing all nationwide centres.',
          type: NotificationType.info,
          icon: Icons.info_outline,
        );
      }
    }
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

  Future<void> _openMaps(CheryServiceCentre centre) async {
    final lat = centre.latitude;
    final lng = centre.longitude;
    final name = centre.name;
    final address = centre.address;

    final Uri navUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=&travelmode=driving');
    final Uri geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(name)})');
    final Uri webSearchUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name, $address')}');

    try {
      bool launched = await launchUrl(navUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        launched = await launchUrl(webSearchUri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        _copyToClipboard(address, 'Address copied: $address');
      }
    } catch (_) {
      try {
        final launched = await launchUrl(webSearchUri, mode: LaunchMode.externalApplication);
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
      AppNotification.show(
        context,
        message: message,
        type: NotificationType.success,
        icon: Icons.copy_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.tokens.accent;
    final onAccent = context.tokens.onAccent;
    final query = _searchController.text.trim().toLowerCase();
    List<CheryServiceCentre> filtered = CheryServiceDirectory.centres.where((centre) {
      final matchesRegion = _selectedRegion == 'All' || centre.region == _selectedRegion;
      final matchesType = _selectedType == 'All' || centre.type == _selectedType;
      final matchesQuery = query.isEmpty ||
          centre.name.toLowerCase().contains(query) ||
          centre.dealerName.toLowerCase().contains(query) ||
          centre.state.toLowerCase().contains(query) ||
          centre.address.toLowerCase().contains(query);
      return matchesRegion && matchesType && matchesQuery;
    }).toList();

    // Sort by proximity when GPS is active
    if (_sortByNearest && _userPosition != null) {
      filtered.sort((a, b) {
        final distA = a.distanceTo(_userPosition!.latitude, _userPosition!.longitude);
        final distB = b.distanceTo(_userPosition!.latitude, _userPosition!.longitude);
        return distA.compareTo(distB);
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine nearest centre if GPS is available
    CheryServiceCentre? closestCentre;
    if (_userPosition != null && filtered.isNotEmpty) {
      closestCentre = filtered.reduce((a, b) {
        final distA = a.distanceTo(_userPosition!.latitude, _userPosition!.longitude);
        final distB = b.distanceTo(_userPosition!.latitude, _userPosition!.longitude);
        return distA < distB ? a : b;
      });
    }

    Widget content = Column(
      children: [
        // 24/7 Roadside Assistance Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF1B2A32), Color(0xFF131922)]
                    : const [Color(0xFFE6FFFA), Color(0xFFF0FDF4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: isDark ? 0.3 : 0.5)),
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
                    children: [
                      Text(
                        'Chery 24/7 Roadside Careline',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF111827)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Toll-Free Nationwide • High Voltage PHEV Rescue',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF4B5563)),
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

        // Nearest Service Centre Hero Banner (Shown when GPS position is available)
        if (closestCentre != null && _sortByNearest)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121A20) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me_rounded, color: Color(0xFF00D2AA), size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'NEAREST SERVICE CENTRE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: isDark ? const Color(0xFF00D2AA) : const Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2AA).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${closestCentre.distanceTo(_userPosition!.latitude, _userPosition!.longitude).toStringAsFixed(1)} km away',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF00D2AA)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              closestCentre.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${closestCentre.dealerName} • ${closestCentre.type} Hub',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF6B7280)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => BookServiceAppointmentSheet.show(context, preselectedCentre: closestCentre),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00D2AA),
                          side: const BorderSide(color: Color(0xFF00D2AA)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Book', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () => _openMaps(closestCentre!),
                        icon: const Icon(Icons.directions, size: 12, color: Colors.black87),
                        label: const Text('Go', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D2AA),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Search Bar & GPS Proximity Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() {}),
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search city, dealer, or state (e.g. Puchong, Ipoh)...',
                    hintStyle: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF00D2AA)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: isDark ? Colors.white60 : const Color(0xFF6B7280)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF131922) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF00D2AA)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // GPS Nearby Action Button
              InkWell(
                onTap: () {
                  if (_userPosition == null) {
                    _requestGpsSort();
                  } else {
                    setState(() {
                      _sortByNearest = !_sortByNearest;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _sortByNearest
                        ? const Color(0xFF00D2AA)
                        : (isDark ? const Color(0xFF131922) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _sortByNearest
                          ? const Color(0xFF00D2AA)
                          : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isLocatingGps)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D2AA)),
                        )
                      else
                        Icon(
                          Icons.near_me_rounded,
                          size: 16,
                          color: _sortByNearest ? Colors.black87 : const Color(0xFF00D2AA),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        _sortByNearest ? 'GPS: On' : 'Nearby',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _sortByNearest ? Colors.black87 : (isDark ? Colors.white70 : const Color(0xFF374151)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                    label: Text(
                      reg,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isSelected ? Colors.black : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedRegion = reg),
                    backgroundColor: isDark ? const Color(0xFF131922) : const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF00D2AA),
                    side: BorderSide(color: isSelected ? const Color(0xFF00D2AA) : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE2E8F0))),
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
                    label: Text(
                      tp == 'All' ? 'All Types' : '$tp Only',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : (isDark ? Colors.white60 : const Color(0xFF4B5563)),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedType = tp),
                    backgroundColor: isDark ? const Color(0xFF131922) : const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF2F81F7),
                    side: BorderSide(color: isSelected ? const Color(0xFF2F81F7) : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE2E8F0))),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  ),
                );
              }),
            ],
          ),
        ),

        // Count indicator & sorting status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _sortByNearest && _userPosition != null
                    ? 'Showing ${filtered.length} centres • Sorted by nearest GPS'
                    : 'Showing ${filtered.length} authorised centres',
                style: TextStyle(
                  fontSize: 11.5,
                  color: (_sortByNearest && _userPosition != null)
                      ? const Color(0xFF00D2AA)
                      : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                  fontWeight: FontWeight.w600,
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final distanceKm = (_userPosition != null)
        ? centre.distanceTo(_userPosition!.latitude, _userPosition!.longitude)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Name, Proximity & Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        centre.name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111827)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        centre.dealerName,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                // Distance Pill (when GPS is active)
                if (distanceKm != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D2AA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me, size: 10, color: Color(0xFF00D2AA)),
                        const SizedBox(width: 3),
                        Text(
                          '${distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00D2AA),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // 4S / 3S Badge
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
                _buildCapabilityBadge(Icons.location_on_outlined, centre.state, isDark ? Colors.white54 : const Color(0xFF6B7280)),
              ],
            ),
            const SizedBox(height: 10),

            // Address Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place, size: 15, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    centre.address,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF4B5563), height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Phone & Hours Row
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF00D2AA)),
                const SizedBox(width: 6),
                Text(
                  centre.phone,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111827)),
                ),
                const Spacer(),
                Icon(Icons.schedule, size: 13, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  centre.operatingHours.split('•').first.trim(),
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                ),
              ],
            ),
            Divider(height: 18, color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE2E8F0)),

            // Action Buttons Row (3 equal width buttons)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(centre.phone),
                    icon: const Icon(Icons.call, size: 13, color: Color(0xFF00D2AA)),
                    label: const Text('Call', style: TextStyle(fontSize: 11.5, color: Color(0xFF00D2AA), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00D2AA)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => BookServiceAppointmentSheet.show(context, preselectedCentre: centre),
                    icon: const Icon(Icons.event_available_rounded, size: 13, color: Color(0xFF2F81F7)),
                    label: const Text('Book', style: TextStyle(fontSize: 11.5, color: Color(0xFF2F81F7), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2F81F7)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openMaps(centre),
                    icon: const Icon(Icons.directions, size: 13, color: Colors.black87),
                    label: const Text('Map', style: TextStyle(fontSize: 11.5, color: Colors.black87, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D2AA),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
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