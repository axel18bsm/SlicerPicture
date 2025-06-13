unit Gui_Interface;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, raylib, raygui, Init, Math;

// Interface utilisateur
procedure DrawRightPanel(var cutter: TImageCutter);
procedure UpdateGUI(var cutter: TImageCutter);
function LoadImageDialog(): string;
procedure CalculateGrid(var cutter: TImageCutter);


// Gestion des contrôles
procedure HandleKeyboardInput(var cutter: TImageCutter);
procedure HandleMouseInput(var cutter: TImageCutter);

implementation
procedure LoadSpecificImage(var cutter: TImageCutter; filename: string);
begin
  with cutter do
  begin
    WriteLn('Tentative de chargement: ', filename);

    if imageLoaded then
    begin
      UnloadTexture(texture);
      WriteLn('Ancienne texture libérée');
    end;

    texture := LoadTexture(PChar(filename));

    if IsTextureValid(texture) then
    begin
      imageLoaded := True;
      imageName := ExtractFileName(filename);
      showFileList := False;  // Masquer la liste après chargement
      CalculateGrid(cutter);
      WriteLn('Image chargée avec succès: ', imageName);
      WriteLn('Dimensions: ', texture.width, 'x', texture.height);
    end
    else
    begin
      WriteLn('ERREUR: Impossible de charger la texture');
      imageLoaded := False;
    end;
  end;
end;



function LoadImageDialog(): string;
begin
  // Chemin en dur pour les tests
  Result := 'ressources/carte1870.png';

  // Vérifier que le fichier existe
  if not FileExists(pchar(Result)) then
  begin
    WriteLn('ERREUR: Fichier non trouvé: ', Result);
    WriteLn('Formats supportés: PNG, JPG, BMP');
    Result := '';
  end
  else
  begin
    WriteLn('Fichier trouvé: ', Result);
  end;
end;

procedure CalculateGrid(var cutter: TImageCutter);
begin
  with cutter do
  begin
    if not imageLoaded or (grid.rows = 0) or (grid.cols = 0) then
    begin
      grid.cellWidth := 0;
      grid.cellHeight := 0;
      Exit;
    end;

    if fixedSquareMode then
    begin
      // Mode carré fixe : tous les carrés ont la même taille
      grid.cellWidth := squareSize;
      grid.cellHeight := squareSize;
      WriteLn('Mode carré fixe: ', grid.rows, 'x', grid.cols, ' carrés de ', squareSize, 'px');
    end
    else
    begin
      // Mode rectangle adaptatif : diviser l'image
      grid.cellWidth := texture.width div grid.cols;
      grid.cellHeight := texture.height div grid.rows;
      WriteLn('Mode rectangle: cellules ', grid.cellWidth, 'x', grid.cellHeight, 'px');
    end;
  end;
end;

procedure DrawImageInfo(var cutter: TImageCutter; x, y: Integer);
var
  infoY: Integer;
begin
  infoY := y;

  with cutter do
  begin
    GuiLabel(RectangleCreate(x, infoY, 180, 20), 'INFORMATIONS IMAGE');
    infoY := infoY + 25;

    if imageLoaded then
    begin
      GuiLabel(RectangleCreate(x, infoY, 150, 15),
               PChar(Format('Fichier: %s', [imageName])));
      infoY := infoY + 20;

      GuiLabel(RectangleCreate(x, infoY, 180, 15),
               PChar(Format('Taille: %dx%d', [texture.width, texture.height])));
      infoY := infoY + 20;
    end
    else
    begin
      GuiLabel(RectangleCreate(x, infoY, 180, 15), 'Aucune image chargée');
      infoY := infoY + 20;
    end;
  end;
end;

procedure DrawGridControls(var cutter: TImageCutter; x, y: Integer);
var
  controlY: Integer;
  spinnerResult: Integer;
  newRows, newCols: Integer;
  sliderValue: Single;
  checkboxResult: Integer;
begin
  controlY := y;

  with cutter do
  begin
    GuiLabel(RectangleCreate(x, controlY, 200, 20), 'PARAMÈTRES GRILLE');
    controlY := controlY + 30;

    // Checkbox mode carré fixe
    checkboxResult := GuiCheckBox(RectangleCreate(x, controlY, 15, 15), 'Mode carré fixe', @fixedSquareMode);
    if checkboxResult <> 0 then
    begin
      if fixedSquareMode then
      WriteLn('Mode changé: Carré fixe')
      else WriteLn('Mode changé:Rectangle adaptatif');
      CalculateGrid(cutter);
    end;
    controlY := controlY + 30;

    // Checkbox mode verso
    checkboxResult := GuiCheckBox(RectangleCreate(x, controlY, 15, 15), 'Mode verso', @versoMode);
    if checkboxResult <> 0 then
    begin
      if versoMode then
        WriteLn('Mode changé: Verso (droite→gauche)')
      else
        WriteLn('Mode changé: Recto (gauche→droite)');
    end;
    controlY := controlY + 30;

    // Contrôles spécifiques au mode carré fixe
    if fixedSquareMode then
    begin
      // Taille du carré : Slider + Spinner
      GuiLabel(RectangleCreate(x, controlY, 100, 15), 'Taille carré:');
      controlY := controlY + 20;

      // Slider
      sliderValue := squareSize;
      if GuiSlider(RectangleCreate(x+10, controlY, 150, 15), '10', '200', @sliderValue, 10, 200) <> 0 then
      begin
        squareSize := Round(sliderValue);
        CalculateGrid(cutter);
        WriteLn('Taille carré (slider): ', squareSize, 'px');
      end;

      // Afficher la valeur
      GuiLabel(RectangleCreate(x + 200, controlY, 50, 15), PChar(IntToStr(squareSize) + 'px'));
      controlY := controlY + 25;
    end;

    // Contrôle nombre de lignes
    if fixedSquareMode then
      GuiLabel(RectangleCreate(x, controlY, 80, 15), 'Lignes:')
    else
      GuiLabel(RectangleCreate(x, controlY, 80, 15), 'Lignes:');
    spinnerResult := GuiSpinner(RectangleCreate(x + 85, controlY, 100, 20), '', @grid.rows, 1, 50, False);
    if spinnerResult <> 0 then
    begin
      CalculateGrid(cutter);
      WriteLn('Nouvelles lignes: ', grid.rows);
    end;
    controlY := controlY + 30;

    // Contrôle nombre de colonnes
    if fixedSquareMode then
      GuiLabel(RectangleCreate(x, controlY, 80, 15), 'Colonnes:')
    else
      GuiLabel(RectangleCreate(x, controlY, 80, 15), 'Colonnes:');
    spinnerResult := GuiSpinner(RectangleCreate(x + 85, controlY, 100, 20), '', @grid.cols, 1, 50, False);
    if spinnerResult <> 0 then
    begin
      CalculateGrid(cutter);
      WriteLn('Nouvelles colonnes: ', grid.cols);
    end;
    controlY := controlY + 30;

    // Affichage informations calculées
    if imageLoaded and (grid.cellWidth > 0) then
    begin
      if fixedSquareMode then
      begin
        GuiLabel(RectangleCreate(x, controlY, 180, 15),
                 PChar(Format('Carrés: %dx%d px', [grid.cellWidth, grid.cellHeight])));
        controlY := controlY + 20;

        GuiLabel(RectangleCreate(x, controlY, 180, 15),
                 PChar(Format('Total carrés: %d', [grid.rows * grid.cols])));
        controlY := controlY + 20;

        GuiLabel(RectangleCreate(x, controlY, 180, 15),
                 PChar(Format('Grille: %dx%d px', [grid.cols * squareSize, grid.rows * squareSize])));
        controlY := controlY + 25;
      end
      else
      begin
        GuiLabel(RectangleCreate(x, controlY, 180, 15),
                 PChar(Format('Taille cellules: %dx%d', [grid.cellWidth, grid.cellHeight])));
        controlY := controlY + 20;

        GuiLabel(RectangleCreate(x, controlY, 180, 15),
                 PChar(Format('Total cellules: %d', [grid.rows * grid.cols])));
        controlY := controlY + 25;
      end;
    end;
  end;
end;

procedure DrawFileControls(var cutter: TImageCutter; x, y: Integer);
var
  controlY: Integer;
  textboxResult: Integer;
  exampleText: string;
begin
  controlY := y;

  with cutter do
  begin
    GuiLabel(RectangleCreate(x, controlY, 150, 20), 'FICHIERS');
    controlY := controlY + 30;

    // Préfixe des fichiers - APPROCHE GLOBALE
    GuiLabel(RectangleCreate(x, controlY, 150, 15), 'Préfixe:');
    controlY := controlY + 20;

    // Initialiser le buffer une seule fois
    SyncPrefixToBuffer(cutter);

    // Utiliser le buffer global directement
    textboxResult := GuiTextBox(RectangleCreate(x, controlY, 120, 20), prefixBuffer, 64, True);

    // Synchroniser le buffer vers la string si modifié
    if textboxResult <> 0 then
    begin
      SyncBufferToPrefix(cutter);
    end;

    controlY := controlY + 30;

    // Dossier de sortie (calculé automatiquement)
    GuiLabel(RectangleCreate(x, controlY, 150, 15), 'Dossier sortie:');
    controlY := controlY + 20;
    GuiLabel(RectangleCreate(x, controlY, 150, 15), PChar('./' + filePrefix + '/'));
    controlY := controlY + 25;

    // Exemple de nom selon le mode
    GuiLabel(RectangleCreate(x, controlY, 150, 15), 'Exemple:');
    controlY := controlY + 20;

    // Générer l'exemple selon le mode actuel
    if cellDisplayMode then
    begin
      if versoMode then
        exampleText := filePrefix + '_1.png (verso)'
      else
        exampleText := filePrefix + '_1.png (recto)';
    end
    else
    begin
      if versoMode then
        exampleText := filePrefix + '_L0C0.png (verso)'
      else
        exampleText := filePrefix + '_L0C0.png (recto)';
    end;

    GuiLabel(RectangleCreate(x, controlY, 220, 15), PChar(exampleText));
  end;
end;

procedure DrawActionButtons(var cutter: TImageCutter; x, y: Integer);
var
  buttonY: Integer;
  gridButtonText: string;
begin
  buttonY := 600;

  with cutter do
  begin
    // Bouton charger/changer image
    if imageLoaded and not showFileList then
    begin
      if GuiButton(RectangleCreate(x, buttonY, 120, 30), 'Changer Image') <> 0 then
      begin
        showFileList := True;
        WriteLn('Retour à la liste de sélection');
      end;
    end
    else
    begin
      if GuiButton(RectangleCreate(x, buttonY, 120, 30), 'Choisir Image') <> 0 then
      begin
        if not showFileList then
        begin
          showFileList := True;
          WriteLn('Affichage de la liste de sélection');
        end;
      end;
    end;
    buttonY := buttonY + 40;

    // Bouton toggle grille
    if grid.visible then
      gridButtonText := 'Masquer Grille'
    else
      gridButtonText := 'Afficher Grille';

    if (GuiButton(RectangleCreate(x, buttonY, 120, 30), PChar(gridButtonText)) <> 0) and imageLoaded then
    begin
      grid.visible := not grid.visible;
      WriteLn('Grille visible: ', grid.visible);
    end;
    buttonY := buttonY + 40;

    // Bouton découpage
    GuiSetState(STATE_NORMAL);
    if not imageLoaded or (grid.rows = 0) or (grid.cols = 0) or showFileList then
      GuiSetState(STATE_DISABLED);

    if GuiButton(RectangleCreate(x, buttonY, 120, 30), 'Lancer Découpage') <> 0 then
    begin
      SaveAllCells(cutter);
    end;

    GuiSetState(STATE_NORMAL);
  end;
end;

procedure DrawRightPanel(var cutter: TImageCutter);
var
  panelX, panelY: Integer;
  currentY: Integer;
  modeText, versoText: string;
begin
  with cutter do
  begin
    panelX := screenWidth - rightPanelWidth;
    panelY := 0;

    // Fond du panneau
    DrawRectangle(panelX, panelY, rightPanelWidth, screenHeight, Fade(LIGHTGRAY, 0.9));
    DrawRectangleLines(panelX, panelY, rightPanelWidth, screenHeight, DARKGRAY);

    currentY := 20;

    // Informations de l'image
    DrawImageInfo(cutter, panelX + 10, currentY);
    currentY := currentY + 100;

    // Contrôles de la grille
    DrawGridControls(cutter, panelX + 10, currentY);
    currentY := currentY + 280;  // Plus d'espace pour le nouveau checkbox

    // Contrôles des fichiers
    DrawFileControls(cutter, panelX + 10, currentY);
    currentY := currentY + 170;

    // Boutons d'action
    DrawActionButtons(cutter, panelX + 10, currentY);

    // Aide clavier
    currentY := screenHeight - 140;
    GuiLabel(RectangleCreate(panelX + 10, currentY, 150, 15), 'RACCOURCIS:');
    currentY := currentY + 20;
    GuiLabel(RectangleCreate(panelX + 10, currentY, 150, 15), 'G: Toggle grille');
    currentY := currentY + 15;
    GuiLabel(RectangleCreate(panelX + 10, currentY, 150, 15), 'Flèches: Déplacer');
    currentY := currentY + 15;
    GuiLabel(RectangleCreate(panelX + 10, currentY, 150, 15), 'M: Mode affichage');
    currentY := currentY + 15;
    GuiLabel(RectangleCreate(panelX + 10, currentY, 150, 15), 'Double-clic: 1 case');
    currentY := currentY + 15;
    GuiLabel(RectangleCreate(panelX + 10, currentY, 150, 15), 'Espace: Découper');

    // Afficher les modes actuels
    if cellDisplayMode then
      modeText := 'Affichage: Numéro'
    else
      modeText := 'Affichage: Coordonnées';
    currentY := currentY + 20;
    GuiLabel(RectangleCreate(panelX + 10, currentY, 150, 15), PChar(modeText));

    if versoMode then
      versoText := 'Parcours: Verso'
    else
      versoText := 'Parcours: Recto';
    currentY := currentY + 15;
    GuiLabel(RectangleCreate(panelX + 10, currentY, 150, 15), PChar(versoText));
  end;
end;

procedure UpdateGUI(var cutter: TImageCutter);
begin
  // Cette fonction sera appelée dans la boucle principale
  // pour mettre à jour l'état de l'interface
end;

procedure HandleKeyboardInput(var cutter: TImageCutter);
begin
  with cutter do
  begin
    // Toggle grille
    if IsKeyPressed(KEY_G) and imageLoaded then
    begin
      grid.visible := not grid.visible;
      WriteLn('Grille visible (clavier): ', grid.visible);
    end;

    // Commuter le mode d'affichage des cellules
    if IsKeyPressed(KEY_M) then
    begin
      cellDisplayMode := not cellDisplayMode;
      if cellDisplayMode then
        WriteLn('Mode affichage: Numéro linéaire')
      else
        WriteLn('Mode affichage: Coordonnées');
    end;

    // Déplacement de la grille - AUTO REPEAT avec IsKeyDown
    if imageLoaded and grid.visible then
    begin
      if IsKeyDown(KEY_RIGHT) then
      begin
        grid.offsetX := grid.offsetX + 1;
      end;
      if IsKeyDown(KEY_LEFT) then
      begin
        grid.offsetX := grid.offsetX - 1;
      end;
      if IsKeyDown(KEY_DOWN) then
      begin
        grid.offsetY := grid.offsetY + 1;
      end;
      if IsKeyDown(KEY_UP) then
      begin
        grid.offsetY := grid.offsetY - 1;
      end;

      // Pas de limitation de déplacement en mode carré fixe (peut dépasser)
      if not fixedSquareMode then
      begin
        // Limiter le déplacement seulement en mode rectangle adaptatif
        if grid.offsetX < -(grid.cellWidth * (grid.cols - 1)) then
          grid.offsetX := -(grid.cellWidth * (grid.cols - 1));
        if grid.offsetX > grid.cellWidth then
          grid.offsetX := grid.cellWidth;
        if grid.offsetY < -(grid.cellHeight * (grid.rows - 1)) then
          grid.offsetY := -(grid.cellHeight * (grid.rows - 1));
        if grid.offsetY > grid.cellHeight then
          grid.offsetY := grid.cellHeight;
      end;
    end;

    // Lancer le découpage
    if IsKeyPressed(KEY_SPACE) and imageLoaded and (grid.rows > 0) and (grid.cols > 0) then
    begin
      SaveAllCells(cutter);
    end;
  end;
end;

procedure HandleMouseInput(var cutter: TImageCutter);
var
  mousePos: TVector2;
  imageArea: TRectangle;
  scale: Single;
  drawWidth, drawHeight: Integer;
  drawX, drawY: Integer;
  relativeX, relativeY: Integer;
  cellX, cellY: Integer;
  wheelMove: Single;
  currentTime: Double;
  timeDiff: Double;
  clickedLine: Integer;
begin
  with cutter do
  begin
    mousePos := GetMousePosition();

    // NOUVEAU: Gestion des clics sur la liste de fichiers
    if showFileList and IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
    begin
      imageArea := RectangleCreate(0, 0, screenWidth - rightPanelWidth, screenHeight);
      if CheckCollisionPointRec(mousePos, imageArea) and (imageFiles.count > 0) then
      begin
        // Calculer quelle ligne est cliquée
        if (mousePos.y >= 100) then
        begin
          clickedLine := Round((mousePos.y - 100) / 30);
          if (clickedLine >= 0) and (clickedLine < imageFiles.count) then
          begin
            WriteLn('Fichier sélectionné: ', ExtractFileName(imageFiles.paths[clickedLine]));
            LoadSpecificImage(cutter, imageFiles.paths[clickedLine]);
          end;
        end;
      end;
      Exit; // Ne pas traiter les autres clics en mode liste
    end;

    // Contrôle de la taille du carré avec la molette (en mode carré fixe)
    if fixedSquareMode then
    begin
      wheelMove := GetMouseWheelMove();
      if wheelMove <> 0 then
      begin
        // Molette vers le haut = augmenter, vers le bas = diminuer
        squareSize := squareSize + Round(wheelMove * 5);  // Pas de 5 pixels

        // Limiter entre 10 et 200
        if squareSize < 10 then squareSize := 10;
        if squareSize > 200 then squareSize := 200;

        CalculateGrid(cutter);
        WriteLn('Taille carré (molette): ', squareSize, 'px');
      end;
    end;

    if not imageLoaded or not grid.visible or showFileList then Exit;

    // Définir la zone de l'image (exclut le panneau droit)
    imageArea := RectangleCreate(0, 0, screenWidth - rightPanelWidth, screenHeight);

    if CheckCollisionPointRec(mousePos, imageArea) and IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
    begin
      currentTime := GetTime();

      // Calculer l'échelle et la position de l'image (même calcul que dans GridRenderer)
      scale := Min(imageArea.width / texture.width, imageArea.height / texture.height);
      drawWidth := Round(texture.width * scale);
      drawHeight := Round(texture.height * scale);
      drawX := Round((imageArea.width - drawWidth) / 2);
      drawY := Round((imageArea.height - drawHeight) / 2);

      // Calculer la position relative dans l'image mise à l'échelle
      relativeX := Round(mousePos.x) - drawX - Round(grid.offsetX * scale);
      relativeY := Round(mousePos.y) - drawY - Round(grid.offsetY * scale);

      // Calculer quelle cellule est sélectionnée
      if (grid.cellWidth > 0) and (grid.cellHeight > 0) then
      begin
        cellX := relativeX div Round(grid.cellWidth * scale);
        cellY := relativeY div Round(grid.cellHeight * scale);

        if (cellX >= 0) and (cellX < grid.cols) and (cellY >= 0) and (cellY < grid.rows) then
        begin
          selectedCellX := cellX;
          selectedCellY := cellY;

          // Gestion du double-clic (300ms)
          if lastClickTime > 0 then
          begin
            timeDiff := (currentTime - lastClickTime) * 1000; // Convertir en millisecondes
            if timeDiff <= 300 then
            begin
              // Double-clic détecté ! Sauvegarder la case
              WriteLn('Double-clic détecté - Sauvegarde case: ', cellX, ',', cellY);
              SaveSingleCell(cutter, cellX, cellY);
              lastClickTime := 0; // Reset pour éviter les triple-clics
            end
            else
            begin
              // Trop tard, c'est un nouveau premier clic
              lastClickTime := currentTime;
            end;
          end
          else
          begin
            // Premier clic
            lastClickTime := currentTime;
          end;

          if cellDisplayMode then
            WriteLn('Case sélectionnée: ', (selectedCellY * grid.cols) + selectedCellX + 1)
          else
            WriteLn('Cellule sélectionnée: ', selectedCellX, ',', selectedCellY);
        end;
      end;
    end;
  end;
end;

end.
