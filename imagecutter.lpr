program imgecutter;

{$mode objfpc}{$H+}

uses
   raylib, raygui, init, SysUtils, Gui_Interface, GridRenderer;

var
  imagecutter: TImageCutter;

begin
  // Initialiser la structure
  initialisation(imagecutter);

  // Initialiser Raylib
  InitWindow(imagecutter.screenWidth, imagecutter.screenHeight, 'Découpeur d''Images - Pascal/Raylib/RayGUI');
  SetTargetFPS(60);

  // Configurer RayGUI
  GuiSetStyle(DEFAULT, TEXT_SIZE, 14);
  GuiSetStyle(DEFAULT, TEXT_SPACING, 1);

  // Utiliser la police personnalisée si chargée
  if imagecutter.fontLoaded then
  begin
    GuiSetFont(imagecutter.customFont);
    WriteLn('Police personnalisée appliquée à RayGUI');
  end;

  WriteLn('=== DÉCOUPEUR D''IMAGES ===');
  WriteLn('Contrôles:');
  WriteLn('- G : Afficher/Masquer grille');
  WriteLn('- Flèches : Déplacer la grille');
  WriteLn('- Espace : Lancer le découpage');
  WriteLn('- Clic + Glisser : Déplacer l''image');
  WriteLn('- Échap : Quitter');
  WriteLn('');
  WriteLn('Interface:');
  WriteLn('- Panneau droit : Contrôles GUI');
  WriteLn('- Spinners pour lignes/colonnes');
  WriteLn('- TextBox pour préfixe de fichier');
  WriteLn('- Liste de sélection d''images');
  WriteLn('');

  // Boucle principale
  while not WindowShouldClose() do
  begin
    // Gestion des entrées
    HandleKeyboardInput(imagecutter);
    HandleMouseInput(imagecutter);

    // Quitter avec Échap
    if IsKeyPressed(KEY_ESCAPE) then
      break;

    // Mise à jour de l'interface
    UpdateGUI(imagecutter);

    // Affichage
    BeginDrawing();
      ClearBackground(RAYWHITE);

      // Dessiner l'image ou la liste de sélection
      DrawImage(imagecutter);

      // Dessiner la grille (seulement si pas en mode liste)
      if not imagecutter.showFileList then
        DrawGrid(imagecutter);

      // Dessiner la cellule sélectionnée (seulement si pas en mode liste)
      if not imagecutter.showFileList then
        DrawSelectedCell(imagecutter);

      // Dessiner l'interface
      DrawRightPanel(imagecutter);

    EndDrawing();
  end;

  // Nettoyage
  if imagecutter.imageLoaded then
  begin
    UnloadTexture(imagecutter.texture);
    WriteLn('Texture libérée');
  end;

  if imagecutter.fontLoaded then
  begin
    UnloadFont(imagecutter.customFont);
    WriteLn('Police personnalisée libérée');
  end;

  // Nettoyage de la liste de fichiers
  if imagecutter.imageFiles.count > 0 then
  begin
    UnloadDirectoryFiles(imagecutter.imageFiles);
    WriteLn('Liste de fichiers libérée');
  end;

  CloseWindow();

  WriteLn('Programme terminé proprement.');
end.
