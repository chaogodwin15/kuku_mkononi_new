import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const KukuMkononiApp());
}

class KukuMkononiApp extends StatelessWidget {
  const KukuMkononiApp({super.key});

  @override
  Widget build(BuildContext context) {
  return MaterialApp(
      title: 'Kuku Mkononi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              if (userSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Firestore Error",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          userSnapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                          ),
                          child: const Text("Go Back"),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                return DashboardScreen(userRole: userData['role'] ?? 'buyer');
              }
              
              return const RoleSelectionScreen();
            },
          );
        }
        
        return const RoleSelectionScreen();
      },
    );
  }
}

// -------------------- ROLE SELECTION SCREEN --------------------
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kuku Mkononi")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen(userRole: "buyer")),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
              child: const Text("Login as Buyer"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen(userRole: "seller")),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
              child: const Text("Login as Seller"),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- LOGIN / REGISTER --------------------
class AuthScreen extends StatefulWidget {
  final String userRole;
  
  const AuthScreen({super.key, required this.userRole});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  Future<void> loginWithPassword() async {
    if (phoneController.text.isNotEmpty && passwordController.text.isNotEmpty) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: '${phoneController.text}@kukumkononi.com',
          password: passwordController.text,
        );
        
      } on FirebaseAuthException catch (e) {
        setState(() {
          errorMessage = e.message;
        });
      } catch (e) {
        setState(() {
          errorMessage = "An unexpected error occurred: $e";
        });
      } finally {
        setState(() => isLoading = false);
      }
    } else {
      setState(() {
        errorMessage = "Please enter both phone number and password";
      });
    }
  }

  Future<void> registerUser() async {
    if (phoneController.text.isNotEmpty && 
        passwordController.text.isNotEmpty && 
        nameController.text.isNotEmpty) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      
      try {
        final UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: '${phoneController.text}@kukumkononi.com',
              password: passwordController.text,
            );

        // FIXED: Added proper error handling for Firestore
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
                'phone': phoneController.text,
                'name': nameController.text,
                'role': widget.userRole,
                'createdAt': FieldValue.serverTimestamp(),
              });
          
          print("User data saved to Firestore successfully!");
          
        } catch (firestoreError) {
          print("Firestore error (user still registered in auth): $firestoreError");
          // User is still registered in Authentication, just Firestore failed
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registered successfully!")),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Registration failed: ${e.message}")),
          );
        }
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${isLogin ? "Login" : "Register"} as ${widget.userRole.capitalize()}"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 20),
                      color: Colors.red[100],
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  
                  if (!isLogin) ...[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Full Name"),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: "Phone Number"),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: "Password"),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  
                  if (isLogin) ...[
                    ElevatedButton(
                      onPressed: loginWithPassword,
                      child: const Text("Login with Password"),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isLogin = false),
                      child: const Text("New user? Register here"),
                    )
                  ] else ...[
                    ElevatedButton(
                      onPressed: registerUser,
                      child: const Text("Register"),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isLogin = true),
                      child: const Text("Already registered? Login here"),
                    )
                  ]
                ],
              ),
            ),
    );
  }
}

// -------------------- CHICKEN MODEL --------------------
class Chicken {
  final String id;
  final String sellerId;
  final String sellerName;
  final String type;
  final double price;
  final int quantity;
  final String description;
  final DateTime createdAt;

  Chicken({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.type,
    required this.price,
    required this.quantity,
    required this.description,
    required this.createdAt,
  });

  factory Chicken.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chicken(
      id: doc.id,
      sellerId: data['sellerId'],
      sellerName: data['sellerName'],
      type: data['type'],
      price: data['price'].toDouble(),
      quantity: data['quantity'],
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

// -------------------- ORDER MODEL --------------------
class Order {
  final String id;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final String chickenId;
  final String chickenType;
  final int quantity;
  final double totalPrice;
  final String status;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.chickenId,
    required this.chickenType,
    required this.quantity,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      buyerId: data['buyerId'],
      buyerName: data['buyerName'],
      sellerId: data['sellerId'],
      sellerName: data['sellerName'],
      chickenId: data['chickenId'],
      chickenType: data['chickenType'],
      quantity: data['quantity'],
      totalPrice: data['totalPrice'].toDouble(),
      status: data['status'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

// -------------------- ADD CHICKEN SCREEN --------------------
class AddChickenScreen extends StatefulWidget {
  const AddChickenScreen({super.key});

  @override
  State<AddChickenScreen> createState() => _AddChickenScreenState();
}

class _AddChickenScreenState extends State<AddChickenScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addChicken() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        await FirebaseFirestore.instance.collection('chickens').add({
          'sellerId': user.uid,
          'sellerName': userDoc['name'],
          'type': _typeController.text,
          'price': double.parse(_priceController.text),
          'quantity': int.parse(_quantityController.text),
          'description': _descriptionController.text,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Chicken added successfully!")),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error adding chicken: $e")),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Chickens")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: "Chicken Type"),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: "Price per Chicken"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: "Quantity Available"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addChicken,
                child: const Text("Add Chicken"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- VIEW CHICKENS SCREEN --------------------
class ViewChickensScreen extends StatelessWidget {
  const ViewChickensScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Available Chickens")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chickens')
            .where('quantity', isGreaterThan: 0)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No chickens available"));
          }
          
          final chickens = snapshot.data!.docs.map((doc) => Chicken.fromFirestore(doc)).toList();
          
          return ListView.builder(
            itemCount: chickens.length,
            itemBuilder: (context, index) {
              final chicken = chickens[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(chicken.type),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Price: TZS ${chicken.price.toStringAsFixed(2)}"),
                      Text("Available: ${chicken.quantity}"),
                      Text("Seller: ${chicken.sellerName}"),
                      if (chicken.description.isNotEmpty)
                        Text("Description: ${chicken.description}"),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaceOrderScreen(chicken: chicken),
                        ),
                      );
                    },
                    child: const Text("Order"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// -------------------- PLACE ORDER SCREEN --------------------
class PlaceOrderScreen extends StatefulWidget {
  final Chicken chicken;
  
  const PlaceOrderScreen({super.key, required this.chicken});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  final TextEditingController _quantityController = TextEditingController();
  bool _isLoading = false;

  Future<void> _placeOrder() async {
    if (_quantityController.text.isEmpty) return;
    
    final quantity = int.parse(_quantityController.text);
    if (quantity <= 0 || quantity > widget.chicken.quantity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid quantity")),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final totalPrice = quantity * widget.chicken.price;

      // Create order
      await FirebaseFirestore.instance.collection('orders').add({
        'buyerId': user.uid,
        'buyerName': userDoc['name'],
        'sellerId': widget.chicken.sellerId,
        'sellerName': widget.chicken.sellerName,
        'chickenId': widget.chicken.id,
        'chickenType': widget.chicken.type,
        'quantity': quantity,
        'totalPrice': totalPrice,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update chicken quantity
      await FirebaseFirestore.instance
          .collection('chickens')
          .doc(widget.chicken.id)
          .update({
            'quantity': widget.chicken.quantity - quantity,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order placed successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error placing order: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Place Order")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Chicken Type: ${widget.chicken.type}", style: const TextStyle(fontSize: 18)),
            Text("Price per Chicken: TZS ${widget.chicken.price.toStringAsFixed(2)}"),
            Text("Available: ${widget.chicken.quantity}"),
            const SizedBox(height: 20),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: "Quantity",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 20),
            if (_quantityController.text.isNotEmpty)
              Text(
                "Total Price: TZS ${(int.tryParse(_quantityController.text) ?? 0) * widget.chicken.price}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _placeOrder,
              child: const Text("Place Order"),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- MY ORDERS SCREEN --------------------
class MyOrdersScreen extends StatelessWidget {
  final String userRole;
  
  const MyOrdersScreen({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final collection = FirebaseFirestore.instance.collection('orders');
    final query = userRole == 'buyer'
        ? collection.where('buyerId', isEqualTo: user.uid)
        : collection.where('sellerId', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(title: Text("My Orders")),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No orders found"));
          }
          
          final orders = snapshot.data!.docs.map((doc) => Order.fromFirestore(doc)).toList();
          
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(order.chickenType),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Quantity: ${order.quantity}"),
                      Text("Total: TZS ${order.totalPrice.toStringAsFixed(2)}"),
                      Text("Status: ${order.status}"),
                      Text("Date: ${order.createdAt.toString().split(' ')[0]}"),
                      if (userRole == 'buyer')
                        Text("Seller: ${order.sellerName}"),
                      if (userRole == 'seller')
                        Text("Buyer: ${order.buyerName}"),
                    ],
                  ),
                  trailing: userRole == 'seller' && order.status == 'pending'
                      ? ElevatedButton(
                          onPressed: () => _confirmOrder(order.id),
                          child: const Text("Confirm"),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': 'confirmed'});
    } catch (e) {
      print("Error confirming order: $e");
    }
  }
}

// -------------------- MY CHICKENS SCREEN --------------------
class MyChickensScreen extends StatelessWidget {
  const MyChickensScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text("My Chickens")),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddChickenScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chickens')
            .where('sellerId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No chickens listed yet"));
          }
          
          final chickens = snapshot.data!.docs.map((doc) => Chicken.fromFirestore(doc)).toList();
          
          return ListView.builder(
            itemCount: chickens.length,
            itemBuilder: (context, index) {
              final chicken = chickens[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(chicken.type),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Price: TZS ${chicken.price.toStringAsFixed(2)}"),
                      Text("Available: ${chicken.quantity}"),
                      if (chicken.description.isNotEmpty)
                        Text("Description: ${chicken.description}"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteChicken(chicken.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteChicken(String chickenId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chickens')
          .doc(chickenId)
          .delete();
    } catch (e) {
      print("Error deleting chicken: $e");
    }
  }
}

// -------------------- LEARN MORE SCREEN --------------------
class LearnMoreScreen extends StatelessWidget {
  const LearnMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About Kuku Mkononi"),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Text(
            "Kuku Mkononi is an innovative application designed to directly connect "
            "buyers and sellers of chicken, eliminating the need for third-party "
            "intermediaries in transactions.\n\n"
            "Sellers can easily list their available chickens and wait for customers "
            "to find them, while buyers can browse through various options, select "
            "their preferred chickens, and place orders with payment on delivery.\n\n"
            "This platform removes the traditional hassles faced by sellers in "
            "finding reliable customers and the challenges buyers encounter when "
            "searching for trustworthy sellers, creating a seamless marketplace "
            "experience for both parties.",
            style: TextStyle(fontSize: 18, height: 1.5),
            textAlign: TextAlign.justify,
          ),
        ),
      ),
    );
  }
}

// -------------------- DASHBOARD --------------------
class DashboardScreen extends StatelessWidget {
  final String userRole;
  
  const DashboardScreen({super.key, required this.userRole});

  Future<void> _callNumber(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number);
    if (!await launchUrl(url)) throw 'Could not call $number';
  }

  Future<void> _sendSMS(String number) async {
    final Uri url = Uri(scheme: 'sms', path: number);
    if (!await launchUrl(url)) throw 'Could not send SMS to $number';
  }

  Future<void> _openWhatsApp(String number) async {
    final Uri url = Uri.parse("https://wa.me/$number");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not open WhatsApp for $number';
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${userRole.capitalize()} Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: userRole == "buyer" 
            ? _buildBuyerDashboardItems(context) 
            : _buildSellerDashboardItems(context),
        ),
      ),
    );
  }

  List<Widget> _buildBuyerDashboardItems(BuildContext context) {
    return [
      _buildDashboardItem(
        icon: Icons.shopping_cart,
        title: "My Cart",
        onTap: () {},
      ),
      _buildDashboardItem(
        icon: Icons.list_alt,
        title: "My Orders",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MyOrdersScreen(userRole: 'buyer')),
          );
        },
      ),
      _buildDashboardItem(
        icon: Icons.search,
        title: "View Chickens",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ViewChickensScreen()),
          );
        },
      ),
      _buildDashboardItem(
        icon: Icons.info,
        title: "Learn More",
        subtitle: "About Kuku Mkononi",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LearnMoreScreen()),
          );
        },
      ),
      _buildDashboardItem(
        icon: Icons.support_agent,
        title: "Customer Support",
        onTap: () {
          _showSupportOptions(context);
        },
      ),
      _buildDashboardItem(
        icon: Icons.logout,
        title: "Logout",
        onTap: () => _logout(context),
      ),
    ];
  }

  List<Widget> _buildSellerDashboardItems(BuildContext context) {
    return [
      _buildDashboardItem(
        icon: Icons.pets,
        title: "My Chickens",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyChickensScreen()),
          );
        },
      ),
      _buildDashboardItem(
        icon: Icons.list_alt,
        title: "My Orders",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MyOrdersScreen(userRole: 'seller')),
          );
        },
      ),
      _buildDashboardItem(
        icon: Icons.add_circle,
        title: "Add Chickens",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddChickenScreen()),
          );
        },
      ),
      _buildDashboardItem(
        icon: Icons.info,
        title: "Learn More",
        subtitle: "About Kuku Mkononi",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LearnMoreScreen()),
          );
        },
      ),
      _buildDashboardItem(
        icon: Icons.support_agent,
        title: "Customer Support",
        onTap: () {
          _showSupportOptions(context);
        },
      ),
      _buildDashboardItem(
        icon: Icons.logout,
        title: "Logout",
        onTap: () => _logout(context),
      ),
    ];
  }

  Widget _buildDashboardItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.call),
            title: const Text("Call Support"),
            onTap: () {
              Navigator.pop(context);
              _callNumber("0758306517");
            },
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text("SMS Support"),
            onTap: () {
              Navigator.pop(context);
              _sendSMS("0758306517");
            },
          ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
            title: const Text("WhatsApp Support"),
            onTap: () {
              Navigator.pop(context);
              _openWhatsApp("255758306517");
            },
          ),
        ],
      ),
    );
  }
}

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}