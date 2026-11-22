const fs = require('fs');
const { execSync } = require('child_process');

// Extract Index.html from the zip to a safe backup location
const psCmd = `Add-Type -AssemblyName System.IO.Compression.FileSystem; 
$zip = [System.IO.Compression.ZipFile]::OpenRead('C:\\Users\\heman\\Downloads\\Flixora-Movie-Finder-main.zip');
$entry = $zip.Entries | Where-Object { $_.FullName -eq 'Flixora-Movie-Finder-main/Index.html' };
$stream = $entry.Open();
$reader = New-Object System.IO.StreamReader($stream);
$content = $reader.ReadToEnd();
$reader.Close();
$stream.Close();
$zip.Dispose();
[System.IO.File]::WriteAllText('C:\\Users\\heman\\Downloads\\Flixora-Movie-Finder-main\\Index.html.backup_preserved', $content, [System.Text.Encoding]::UTF8);
`;

fs.writeFileSync('extract_backup.ps1', psCmd);
console.log('Script written to extract Index.html backup.');

