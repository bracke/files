separate (Files_Suite.Model)
   procedure Test_Document_Media_And_Source_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Png_Path  : constant String := Join (Root, "picture.png");
      Jpeg_Path : constant String := Join (Root, "photo.jpg");
      Pdf_Path  : constant String := Join (Root, "paper.pdf");
      Pdf_Control_Path : constant String := Join (Root, "paper-control.pdf");
      Zip_Path  : constant String := Join (Root, "bundle.zip");
      Split_Zip_Path : constant String := Join (Root, "split.zip");
      Docx_Path : constant String := Join (Root, "report.docx");
      Xlsx_Path : constant String := Join (Root, "sheet.xlsx");
      Mp3_Path  : constant String := Join (Root, "track.mp3");
      Mp4_Path  : constant String := Join (Root, "clip.mp4");
      Tar_Gz_Path : constant String := Join (Root, "archive.tar.gz");
      Ada_Path  : constant String := Join (Root, "unit.adb");
      Json_Path : constant String := Join (Root, "data.json");
      Xml_Path  : constant String := Join (Root, "doc.xml");
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load      : Files.File_System.Directory_Load_Result;
      Found_Png : Boolean := False;
      Found_Jpeg : Boolean := False;
      Found_Dir : Boolean := False;
      Found_Pdf : Boolean := False;
      Found_Pdf_Control : Boolean := False;
      Found_Zip : Boolean := False;
      Found_Split_Zip : Boolean := False;
      Found_Docx : Boolean := False;
      Found_Xlsx : Boolean := False;
      Found_Mp3 : Boolean := False;
      Found_Mp4 : Boolean := False;
      Found_Tar_Gz : Boolean := False;
      Found_Ada : Boolean := False;
      Found_Json : Boolean := False;
      Found_Xml : Boolean := False;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "folder"));
      Write_File (Join (Join (Root, "folder"), "inside.txt"));
      Write_Binary_File (Png_Path, Minimal_Png_Header (32, 16));
      Write_Binary_File (Jpeg_Path, Minimal_Jpeg_With_Fill (48, 24));
      Write_File
        (Pdf_Path,
         "%PDF-1.7" & ASCII.LF &
         "1 0 obj /Type /Pages endobj" & ASCII.LF &
         "2 0 obj /Type /Page endobj");
      Write_File
        (Pdf_Control_Path,
         "%PDF-1.7" & ASCII.LF &
         "1 0 obj /Type /Page" & ASCII.VT & "endobj" & ASCII.LF &
         "2 0 obj /Type /Page" & ASCII.FF & "endobj");
      Write_Binary_File (Zip_Path, "PK" & Character'Val (1) & Character'Val (2));
      Write_Binary_File
        (Split_Zip_Path,
         String'(1 .. 4094 => 'x') & "PK" & Character'Val (1) & Character'Val (2));
      Write_Binary_File (Docx_Path, "PK" & Character'Val (1) & Character'Val (2));
      Write_Binary_File (Xlsx_Path, "PK" & Character'Val (1) & Character'Val (2));
      Write_File (Mp3_Path, "ID3");
      Write_File (Mp4_Path, "....ftyp");
      Write_Binary_File (Tar_Gz_Path, Character'Val (16#1F#) & Character'Val (16#8B#) & "gzip");
      Write_File (Ada_Path, "procedure Unit is" & ASCII.LF & "begin" & ASCII.LF & "null;" & ASCII.LF & "end;");
      Write_File (Json_Path, "{""ok"":true}");
      Write_File (Xml_Path, "<root/>");

      Load := Files.File_System.Load_Directory (Root, Settings);

      for Item of Load.Items loop
         if To_String (Item.Name) = "picture.png" then
            Found_Png := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "image.dimensions|32x16",
               "PNG dimensions are loaded as filetype-specific metadata");
         elsif To_String (Item.Name) = "photo.jpg" then
            Found_Jpeg := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "image.dimensions|48x24",
               "JPEG dimensions tolerate fill bytes before frame markers");
         elsif To_String (Item.Name) = "folder" then
            Found_Dir := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "directory.count|1",
               "directory item counts are loaded as filetype-specific metadata");
         elsif To_String (Item.Name) = "paper.pdf" then
            Found_Pdf := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/pdf",
               "PDF extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "document.pdf.pages|1",
               "PDF files expose page marker metadata");
         elsif To_String (Item.Name) = "paper-control.pdf" then
            Found_Pdf_Control := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "document.pdf.pages|2",
               "PDF page markers accept vertical tab and form feed separators");
         elsif To_String (Item.Name) = "bundle.zip" then
            Found_Zip := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/zip",
               "ZIP extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "archive.zip.entries|1",
               "ZIP files expose entry-count metadata");
         elsif To_String (Item.Name) = "split.zip" then
            Found_Split_Zip := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "archive.zip.entries|1",
               "ZIP entry counting detects signatures split across read buffers");
         elsif To_String (Item.Name) = "report.docx" then
            Found_Docx := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
               "DOCX extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "office.docx.entries|1",
               "DOCX files expose package entry-count metadata");
         elsif To_String (Item.Name) = "sheet.xlsx" then
            Found_Xlsx := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
               "XLSX extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "office.xlsx.entries|1",
               "XLSX files expose package entry-count metadata");
         elsif To_String (Item.Name) = "track.mp3" then
            Found_Mp3 := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "audio/mpeg",
               "MP3 extension maps to filetype");
            Files_Suite.Support.Assert_Equal (Item_Extra (Item), "media.kind|audio", "MP3 files expose audio metadata");
         elsif To_String (Item.Name) = "clip.mp4" then
            Found_Mp4 := True;
            Files_Suite.Support.Assert_Equal (To_String (Item.Filetype), "video/mp4", "MP4 extension maps to filetype");
            Files_Suite.Support.Assert_Equal (Item_Extra (Item), "media.kind|video", "MP4 files expose video metadata");
         elsif To_String (Item.Name) = "archive.tar.gz" then
            Found_Tar_Gz := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/gzip-tar",
               "compound extension maps to filetype; got "
               & To_String (Item.Filetype));
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "archive.format|gzip",
               "compound gzip-tar archive files expose gzip format metadata");
         elsif To_String (Item.Name) = "unit.adb" then
            Found_Ada := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "text/x-ada",
               "Ada body extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "source.ada.lines_encoding|4|ascii",
               "Ada source files expose source metadata");
         elsif To_String (Item.Name) = "data.json" then
            Found_Json := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/json",
               "JSON extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "source.json.lines_encoding|1|ascii",
               "JSON files expose source metadata");
         elsif To_String (Item.Name) = "doc.xml" then
            Found_Xml := True;
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "application/xml",
               "XML extension maps to filetype");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "source.xml.lines_encoding|1|ascii",
               "XML files expose source metadata");
         end if;
      end loop;

      Assert (Found_Png, "PNG item was loaded");
      Assert (Found_Jpeg, "JPEG item was loaded");
      Assert (Found_Dir, "directory item was loaded");
      Assert (Found_Pdf, "PDF item was loaded");
      Assert (Found_Pdf_Control, "PDF control-whitespace item was loaded");
      Assert (Found_Zip, "ZIP item was loaded");
      Assert (Found_Split_Zip, "split ZIP item was loaded");
      Assert (Found_Docx, "DOCX item was loaded");
      Assert (Found_Xlsx, "XLSX item was loaded");
      Assert (Found_Mp3, "MP3 item was loaded");
      Assert (Found_Mp4, "MP4 item was loaded");
      Assert (Found_Tar_Gz, "compound archive item was loaded");
      Assert (Found_Ada, "Ada item was loaded");
      Assert (Found_Json, "JSON item was loaded");
      Assert (Found_Xml, "XML item was loaded");
   end Test_Document_Media_And_Source_Metadata;
