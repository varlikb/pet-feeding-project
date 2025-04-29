import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pet_provider.dart';
import 'pet_detail_screen.dart';
import 'register_pet_screen.dart';

class PetsListScreen extends StatefulWidget {
  const PetsListScreen({Key? key}) : super(key: key);

  @override
  State<PetsListScreen> createState() => _PetsListScreenState();
}

class _PetsListScreenState extends State<PetsListScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPets();
    });
  }

  Future<void> _loadPets() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await Provider.of<PetProvider>(context, listen: false).fetchPets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading pets: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<PetProvider>(
              builder: (context, petProvider, child) {
                final pets = petProvider.pets;
                
                if (pets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.pets,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No pets found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add your first pet to get started',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add a Pet'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const RegisterPetScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }
                
                return RefreshIndicator(
                  onRefresh: _loadPets,
                  child: ListView.builder(
                    itemCount: pets.length,
                    itemBuilder: (context, index) {
                      final pet = pets[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            child: Icon(
                              pet.isFemale ? Icons.female : Icons.male,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            pet.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${pet.age} years • ${pet.weight} kg',
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: () async {
                            try {
                              await petProvider.selectPet(pet.id);
                              if (context.mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const PetDetailScreen(),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error selecting pet: $e')),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const RegisterPetScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 