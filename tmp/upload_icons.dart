import 'dart:io';

void main() async {
  final file = File('../assets/icons/category_icons.json');
  if (!await file.exists()) {
    print('Fichier non trouvé: ${file.path}');
    return;
  }

  final content = await file.readAsString();
  final curlCommand = '''
curl -X POST "https://trfhpcrgzjkfyxmroooa.supabase.co/storage/v1/object/config-files/category_icons.json" \\
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyZmhwY3JnemprZnl4bXJvb29hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ1NDY5NjMsImV4cCI6MjA3MDEyMjk2M30.AhkRqvmmbCmdwAJWefgAWdKELBApOHppNte7Xx68aoE" \\
  -H "Content-Type: application/json" \\
  -d '$content'
''';

  // Écrire dans un fichier temporaire
  final tempFile = File('temp_upload.sh');
  await tempFile.writeAsString(curlCommand);
  print('\nCommande sauvegardée dans temp_upload.sh');
  print('Exécutez: bash temp_upload.sh');
}
