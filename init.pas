unit Init;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, raylib, raygui;
 const
    SCREENWIDTH: Integer = 1280;
    SCREENHEIGHT: Integer = 800;
type
  TGridState = record
    visible: Boolean;
    offsetX, offsetY: Integer;
    rows, cols: Integer;
    cellWidth, cellHeight: Integer;
  end;

  TImageCutter = record
    // Fenêtre et affichage
    screenWidth, screenHeight: Integer;

    // Image source
    texture: TTexture2D;
    imageLoaded: Boolean;
    imagePath: string;
    imageName: string;

    // Grille de découpage
    grid: TGridState;
    selectedCellX, selectedCellY: Integer;
    cellDisplayMode: Boolean;  // False = coordonnées (0,1), True = numéro (1)

    // Mode carré fixe
    fixedSquareMode: Boolean;  // False = mode rectangle, True = mode carré fixe
    squareSize: Integer;       // Taille du carré en pixels
    newSquareSize: Integer;

    // Mode verso (parcours inverse)
    versoMode: Boolean;        // False = recto (normal), True = verso (inverse)

    // Interface utilisateur
    rightPanelWidth: Integer;

    // Paramètres de découpage
    filePrefix: string;
    outputFolder: string;

    // Police pour l'interface
    customFont: TFont;
    fontLoaded: Boolean;

    // Buffers globaux pour RayGUI
    prefixBuffer: array[0..63] of Char;
    prefixBufferInitialized: Boolean;

    // Système de double-clic
    lastClickTime: Double;
    doubleClickDetected: Boolean;
    // NOUVELLES variables pour la sélection de fichiers
    showFileList: Boolean;
    imageFiles: TFilePathList;  // Structure Raylib native
    // NOUVELLES variables pour la navigation 1:1
    imageOffsetX, imageOffsetY: Integer;  // Position de l'image
    isDragging: Boolean;                  // État glisser-déposer
    lastMouseX, lastMouseY: Integer;      // Position souris précédent
  end;


var
imgecutter :TImageCutter;

procedure initialisation(Var imgecutter:TImageCutter);
procedure SyncPrefixToBuffer(var cutter: TImageCutter);
procedure SyncBufferToPrefix(var cutter: TImageCutter);

// Fonctions de sauvegarde
function GenerateFileName(const prefix: string; cellX, cellY, cols: Integer; displayMode, versoMode: Boolean): string;
function SaveSingleCell(var cutter: TImageCutter; cellX, cellY: Integer): Boolean;
procedure SaveAllCells(var cutter: TImageCutter);

implementation

procedure ScanImageFiles(var cutter: TImageCutter);
begin
  with cutter do
  begin
    // Libérer l'ancienne liste si elle existe
    if imageFiles.count > 0 then
      UnloadDirectoryFiles(imageFiles);

    // Scanner le dossier ressources avec filtrage automatique
    imageFiles := LoadDirectoryFilesEx('ressources', '.png;.jpg;.bmp', false);

    WriteLn('Fichiers images trouvés: ', imageFiles.count);
  end;
end;

procedure LoadCustomFont(var cutter: TImageCutter);
const
  FONT_SIZE = 16;
  FRENCH_CHARS = ' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~' +
                 'ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ' +
                 '€''""…–—';
var
  codepoints: array of Integer;
  i: Integer;
begin
  with cutter do
  begin
    if FileExists('ressources/roboto.ttf') then
    begin
      SetLength(codepoints, Length(FRENCH_CHARS));
      for i := 0 to Length(FRENCH_CHARS) - 1 do
        codepoints[i] := Ord(FRENCH_CHARS[i + 1]);

      customFont := LoadFontEx('ressources/Roboto.ttf', FONT_SIZE, @codepoints[0], Length(codepoints));
      fontLoaded := True;
      WriteLn('Police personnalisée chargée avec caractères français');
    end
    else
    begin
      customFont := GetFontDefault();
      fontLoaded := False;
      WriteLn('Police par défaut utilisée - Fichier roboto.ttf non trouvé');
    end;
  end;
end;

procedure SyncPrefixToBuffer(var cutter: TImageCutter);
begin
  with cutter do
  begin
    if not prefixBufferInitialized then
    begin
      StrPCopy(prefixBuffer, filePrefix);
      prefixBufferInitialized := True;
      WriteLn('Buffer préfixe initialisé avec: ', filePrefix);
    end;
  end;
end;

procedure SyncBufferToPrefix(var cutter: TImageCutter);
var
  newPrefix: string;
begin
  with cutter do
  begin
    newPrefix := StrPas(prefixBuffer);
    if newPrefix <> filePrefix then
    begin
      filePrefix := newPrefix;
      WriteLn('Préfixe mis à jour: ', filePrefix);
    end;
  end;
end;

function GenerateFileName(const prefix: string; cellX, cellY, cols: Integer; displayMode, versoMode: Boolean): string;
var
  cellNumber: Integer;
  virtualX: Integer;
begin
  // Calculer la coordonnée X virtuelle selon le mode
  if versoMode then
    virtualX := (cols - 1) - cellX  // Inverser la position X pour le mode verso
  else
    virtualX := cellX;              // Position normale pour le mode recto

  if displayMode then
  begin
    // Mode numéro linéaire : calculer le numéro de la case avec virtualX
    cellNumber := (cellY * cols) + virtualX + 1;
    WriteLn('DEBUG: cellY=', cellY, ' cellX=', cellX, ' virtualX=', virtualX, ' cols=', cols, ' → numero=', cellNumber);
    Result := prefix + '_' + IntToStr(cellNumber) + '.png';
  end
  else
  begin
    // Mode coordonnées : utiliser virtualX pour le nom
    WriteLn('DEBUG: cellY=', cellY, ' cellX=', cellX, ' virtualX=', virtualX, ' → L', cellY, 'C', virtualX);
    Result := prefix + '_L' + IntToStr(cellY) + 'C' + IntToStr(virtualX) + '.png';
  end;
end;

function SaveSingleCell(var cutter: TImageCutter; cellX, cellY: Integer): Boolean;
var
  sourceImage: TImage;
  cellImage: TImage;
  cellRect: TRectangle;
  fileName: string;
  outputPath: string;
  startX, startY: Integer;
begin
  Result := False;

  with cutter do
  begin
    // Vérifier que la case est valide
    if (cellX < 0) or (cellX >= grid.cols) or (cellY < 0) or (cellY >= grid.rows) then
    begin
      WriteLn('ERREUR: Case invalide (', cellX, ',', cellY, ')');
      Exit;
    end;

    // Calculer les coordonnées réelles de la case
    startX := grid.offsetX + (cellX * grid.cellWidth);
    startY := grid.offsetY + (cellY * grid.cellHeight);

    // Vérifier que la case ne dépasse pas l'image (ignorer si c'est le cas)
    if (startX + grid.cellWidth > texture.width) or (startY + grid.cellHeight > texture.height) or
       (startX < 0) or (startY < 0) then
    begin
      WriteLn('Case ignorée (dépasse l''image): ', cellX, ',', cellY);
      Exit;
    end;

    // Créer le dossier de sortie si nécessaire
    outputPath := './' + filePrefix + '/';
    if not DirectoryExists(pchar(outputPath)) then
    begin
      if not CreateDir(outputPath) then
      begin
        WriteLn('ERREUR: Impossible de créer le dossier: ', outputPath);
        Exit;
      end;
      WriteLn('Dossier créé: ', outputPath);
    end;

    // Convertir la texture en image
    sourceImage := LoadImageFromTexture(texture);

    // Définir le rectangle à extraire
    cellRect := RectangleCreate(startX, startY, grid.cellWidth, grid.cellHeight);

    // Extraire la partie de l'image
    cellImage := ImageFromImage(sourceImage, cellRect);

    // Générer le nom de fichier avec le mode verso
    fileName := GenerateFileName(filePrefix, cellX, cellY, cutter.grid.cols, cellDisplayMode, versoMode);

    // Sauvegarder l'image
    if ExportImage(cellImage, PChar(outputPath + fileName)) then
    begin
      WriteLn('Case sauvegardée: ', outputPath + fileName);
      Result := True;
    end
    else
    begin
      WriteLn('ERREUR: Échec sauvegarde: ', fileName);
    end;

    // Libérer la mémoire
    UnloadImage(cellImage);
    UnloadImage(sourceImage);
  end;
end;

procedure SaveAllCells(var cutter: TImageCutter);
var
  cellX, cellY: Integer;
  savedCount, ignoredCount: Integer;
begin
  savedCount := 0;
  ignoredCount := 0;

  with cutter do
  begin
    if not imageLoaded then
    begin
      WriteLn('ERREUR: Aucune image chargée');
      Exit;
    end;

    if (grid.rows = 0) or (grid.cols = 0) then
    begin
      WriteLn('ERREUR: Grille invalide');
      Exit;
    end;

    WriteLn('=== DÉBUT DU DÉCOUPAGE ===');
    WriteLn('Grille: ', grid.rows, ' lignes × ', grid.cols, ' colonnes');
    if fixedSquareMode  then
    WriteLn('Mode: Carrés fixes')
    else
   WriteLn('Mode: Rectangles adaptatifs');
    if versoMode then
    WriteLn('Parcours: Verso ')
    else
      WriteLn('Parcours: Recto ');
    WriteLn('Préfixe: ', filePrefix);
    WriteLn('');

    // Parcourir toutes les cases selon le mode
    for cellY := 0 to grid.rows - 1 do
    begin
      if versoMode then
      begin
        // Mode verso : parcours de droite à gauche
        for cellX := grid.cols - 1 downto 0 do
        begin
          if SaveSingleCell(cutter, cellX, cellY) then
            Inc(savedCount)
          else
            Inc(ignoredCount);
        end;
      end
      else
      begin
        // Mode recto : parcours de gauche à droite (normal)
        for cellX := 0 to grid.cols - 1 do
        begin
          if SaveSingleCell(cutter, cellX, cellY) then
            Inc(savedCount)
          else
            Inc(ignoredCount);
        end;
      end;
    end;

    WriteLn('');
    WriteLn('=== DÉCOUPAGE TERMINÉ ===');
    WriteLn('Cases sauvegardées: ', savedCount);
    WriteLn('Cases ignorées: ', ignoredCount);
    WriteLn('Total traité: ', savedCount + ignoredCount);
  end;
end;

procedure initialisation(Var imgecutter:TImageCutter);
begin
   // Initialiser la structure imgecutter directement
  // Paramètres de fenêtre
  imgeCutter.screenWidth := SCREENWIDTH;
  imgecutter.screenHeight := SCREENHEIGHT;
  imgecutter.rightPanelWidth := 300;

  // État initial
  imgecutter.imageLoaded := False;
  imgecutter.imagePath := '';
  imgecutter.imageName := '';

  // Grille par défaut
  imgecutter.grid.visible := False;
  imgecutter.grid.offsetX := 0;
  imgecutter.grid.offsetY := 0;
  imgecutter.grid.rows := 3;
  imgecutter.grid.cols := 3;
  imgecutter.grid.cellWidth := 0;
  imgecutter.grid.cellHeight := 0;

  // Sélection
  imgecutter.selectedCellX := -1;
  imgecutter.selectedCellY := -1;
  imgecutter.cellDisplayMode := False;  // Commencer par le mode coordonnées

  // Mode carré fixe
  imgecutter.fixedSquareMode := False;  // Commencer par le mode rectangle
  imgecutter.squareSize := 50;          // Taille par défaut 50 pixels

  // Mode verso
  imgecutter.versoMode := False;        // Commencer par le mode recto

  // Paramètres de fichiers
  imgecutter.filePrefix := 'savedpictures';
  imgecutter.outputFolder := '';

  // Buffers globaux
  imgecutter.prefixBufferInitialized := False;
  FillChar(imgecutter.prefixBuffer, SizeOf(imgecutter.prefixBuffer), 0);

  // Système de double-clic
  imgecutter.lastClickTime := 0;
  imgecutter.doubleClickDetected := False;

  // Charger la police personnalisée avec support des accents français
  LoadCustomFont(imgecutter);
  // NOUVELLES initialisations à ajouter à la fin
  imgecutter.showFileList := True;  // Commencer par afficher la liste
  imgecutter.imageFiles.count := 0;
  imgecutter.imageFiles.paths := nil;

  // Navigation image
  imgecutter.imageOffsetX := 0;
  imgecutter.imageOffsetY := 0;
  imgecutter.isDragging := False;
  imgecutter.lastMouseX := 0;
  imgecutter.lastMouseY := 0;

  // Scanner les fichiers au démarrage
  ScanImageFiles(imgecutter);
end;

initialization
end.
