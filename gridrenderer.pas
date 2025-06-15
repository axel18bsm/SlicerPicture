unit GridRenderer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, raylib, Init, Math;

procedure DrawImage(const cutter: TImageCutter);
procedure DrawGrid(const cutter: TImageCutter);
procedure DrawSelectedCell(const cutter: TImageCutter);

implementation

procedure DrawFileList(const cutter: TImageCutter);
var
  i: Integer;
  yPos: Integer;
  imageArea: TRectangle;
  fileName: string;
begin
  with cutter do
  begin
    // Définir la zone d'affichage (même que pour l'image)
    imageArea := RectangleCreate(0, 0, screenWidth - rightPanelWidth, screenHeight);
    DrawRectangleRec(imageArea, RAYWHITE);
    DrawRectangleLinesEx(imageArea, 2, LIGHTGRAY);

    if imageFiles.count = 0 then
    begin
      // Aucun fichier trouvé
      DrawText('Aucun fichier image trouvé dans ressources/',
               (screenWidth - rightPanelWidth) div 2 - 150,
               screenHeight div 2,
               20, GRAY);
      Exit;
    end;

    // Titre
    DrawText('Choisir une image:',
             50, 50, 24, DARKGRAY);

    // Lister les fichiers
    yPos := 100;
    for i := 0 to imageFiles.count - 1 do
    begin
      fileName := ExtractFileName(imageFiles.paths[i]);
      DrawText(PChar(fileName), 50, yPos, 20, BLACK);
      yPos := yPos + 30;

      // Ne pas dépasser la zone
      if yPos > screenHeight - 100 then
        Break;
    end;
  end;
end;

procedure DrawImage(const cutter: TImageCutter);
var
  imageArea: TRectangle;
  drawX, drawY: Integer;
  clipRect: TRectangle;
  sourceRect: TRectangle;
  destRect: TRectangle;
begin
  with cutter do
  begin
    // Si on doit afficher la liste au lieu de l'image
    if showFileList then
    begin
      DrawFileList(cutter);
      Exit;
    end;

    if not imageLoaded then
    begin
      // Dessiner un fond vide
      imageArea := RectangleCreate(0, 0, screenWidth - rightPanelWidth, screenHeight);
      DrawRectangleRec(imageArea, RAYWHITE);
      DrawRectangleLinesEx(imageArea, 2, LIGHTGRAY);

      // Message au centre
      DrawText('Aucune image chargée',
               (screenWidth - rightPanelWidth) div 2 - 80,
               screenHeight div 2,
               20, GRAY);
      Exit;
    end;

    // Zone d'affichage disponible
    imageArea := RectangleCreate(0, 0, screenWidth - rightPanelWidth, screenHeight);

    // Position de l'image (échelle 1:1)
    drawX := imageOffsetX;
    drawY := imageOffsetY;

    // Calculer la partie visible de l'image
    sourceRect.x := 0;
    sourceRect.y := 0;
    sourceRect.width := texture.width;
    sourceRect.height := texture.height;

    destRect.x := drawX;
    destRect.y := drawY;
    destRect.width := texture.width;
    destRect.height := texture.height;

    // Appliquer le clipping pour ne dessiner que la partie visible
    if drawX < 0 then
    begin
      sourceRect.x := -drawX;
      sourceRect.width := sourceRect.width + drawX;
      destRect.x := 0;
      destRect.width := destRect.width + drawX;
    end;

    if drawY < 0 then
    begin
      sourceRect.y := -drawY;
      sourceRect.height := sourceRect.height + drawY;
      destRect.y := 0;
      destRect.height := destRect.height + drawY;
    end;

    if destRect.x + destRect.width > imageArea.width then
    begin
      sourceRect.width := sourceRect.width - ((destRect.x + destRect.width) - imageArea.width);
      destRect.width := destRect.width - ((destRect.x + destRect.width) - imageArea.width);
    end;

    if destRect.y + destRect.height > imageArea.height then
    begin
      sourceRect.height := sourceRect.height - ((destRect.y + destRect.height) - imageArea.height);
      destRect.height := destRect.height - ((destRect.y + destRect.height) - imageArea.height);
    end;

    // Dessiner seulement la partie visible de l'image
    if (sourceRect.width > 0) and (sourceRect.height > 0) then
    begin
      DrawTexturePro(texture, sourceRect, destRect, Vector2Create(0, 0), 0, WHITE);
    end;
  end;
end;

procedure DrawGrid(const cutter: TImageCutter);
var
  imageArea: TRectangle;
  drawX, drawY: Integer;
  i, j: Integer;
  lineX, lineY: Integer;
begin
  with cutter do
  begin
    if not imageLoaded or not grid.visible or (grid.rows = 0) or (grid.cols = 0) or showFileList then
      Exit;

    // Zone d'affichage disponible
    imageArea := RectangleCreate(0, 0, screenWidth - rightPanelWidth, screenHeight);

    // Position de l'image (échelle 1:1)
    drawX := imageOffsetX;
    drawY := imageOffsetY;

    // Dessiner les lignes verticales
    for i := 0 to grid.cols do
    begin
      lineX := drawX + grid.offsetX + (i * grid.cellWidth);
      if (lineX >= 0) and (lineX <= imageArea.width) then
        DrawLine(lineX, Max(0, drawY), lineX, Min(Round(imageArea.height), drawY + texture.height), BLACK);
    end;

    // Dessiner les lignes horizontales
    for j := 0 to grid.rows do
    begin
      lineY := drawY + grid.offsetY + (j * grid.cellHeight);
      if (lineY >= 0) and (lineY <= imageArea.height) then
        DrawLine(Max(0, drawX), lineY, Min(Round(imageArea.width), drawX + texture.width), lineY, BLACK);
    end;
  end;
end;

procedure DrawSelectedCell(const cutter: TImageCutter);
var
  imageArea: TRectangle;
  scale: Single;
  drawWidth, drawHeight: Integer;
  drawX, drawY: Integer;
  cellDrawWidth, cellDrawHeight: Integer;
  selectedRect: TRectangle;
  cellNumber: Integer;
  displayText: string;
begin
  with cutter do
  begin
    if not imageLoaded or not grid.visible or (grid.rows = 0) or (grid.cols = 0) then
      Exit;

    if (selectedCellX < 0) or (selectedCellX >= grid.cols) or
       (selectedCellY < 0) or (selectedCellY >= grid.rows) then
      Exit;

    // Calculer la même échelle que pour l'image
    imageArea := RectangleCreate(0, 0, screenWidth - rightPanelWidth, screenHeight);
    scale := Min(imageArea.width / texture.width, imageArea.height / texture.height);

    drawWidth := Round(texture.width * scale);
    drawHeight := Round(texture.height * scale);
    drawX := Round((imageArea.width - drawWidth) / 2);
    drawY := Round((imageArea.height - drawHeight) / 2);

    // Calculer la taille des cellules à l'échelle
    cellDrawWidth := Round(grid.cellWidth * scale);
    cellDrawHeight := Round(grid.cellHeight * scale);

    // Calculer la position du rectangle de sélection
    selectedRect.x := drawX + Round(grid.offsetX * scale) + (selectedCellX * cellDrawWidth);
    selectedRect.y := drawY + Round(grid.offsetY * scale) + (selectedCellY * cellDrawHeight);
    selectedRect.width := cellDrawWidth;
    selectedRect.height := cellDrawHeight;

    // Dessiner le rectangle de sélection avec une couleur différente
    DrawRectangleLinesEx(selectedRect, 3, RED);
    DrawRectangleRec(selectedRect, Fade(RED, 0.2));

    // Choisir le texte selon le mode d'affichage
    if cellDisplayMode then
    begin
      // Mode numéro linéaire (1, 2, 3...)
      cellNumber := (selectedCellY * grid.cols) + selectedCellX + 1;
      displayText := Format('Case: %d', [cellNumber]);
    end
    else
    begin
      // Mode coordonnées (0,1 - 1,2...)
      displayText := Format('Cellule: %d,%d', [selectedCellX, selectedCellY]);
    end;

    // Afficher le texte choisi
    DrawText(PChar(displayText),
             Round(selectedRect.x),
             Round(selectedRect.y - 20),
             16, RED);
  end;
end;

end.
