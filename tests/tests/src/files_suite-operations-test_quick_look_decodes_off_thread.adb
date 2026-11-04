with Files.Images;
with Files.Preview_Decoder;
with Files.Quick_Look;
separate (Files_Suite.Operations)
   procedure Test_Quick_Look_Decodes_Off_Thread (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Quick_Look.Content_Kind;
      Jpeg_Hex : constant String :=
           "FFD8FFE000104A46494600010100000100010000FFDB0043000302020302020303030304030304050805050404050A07" &
           "0706080C0A0C0C0B0A0B0B0D0E12100D0E110E0B0B1016101113141515150C0F171816141812141514FFDB0043010304" &
           "0405040509050509140D0B0D141414141414141414141414141414141414141414141414141414141414141414141414" &
           "1414141414141414141414141414FFC00011080008000803011100021101031101FFC400140001000000000000000000" &
           "00000000000008FFC40014100100000000000000000000000000000000FFC40015010101000000000000000000000000" &
           "00000709FFC40014110100000000000000000000000000000000FFDA000C03010002110311003F003A03154DFFD9";
      First  : constant String := Join (Root, "first.jpg");
      Second : constant String := Join (Root, "second.jpg");
      Bytes  : String (1 .. Jpeg_Hex'Length / 2);
      Image  : Files.Images.Decoded_Image;
      Ready  : Boolean := False;
      Model  : Files.Model.Window_Model;
   begin
      Reset_Root;
      for Index in Bytes'Range loop
         Bytes (Index) :=
           Byte (Natural'Value ("16#" & Jpeg_Hex (Jpeg_Hex'First + 2 * (Index - 1) .. Jpeg_Hex'First + 2 * Index - 1)
                                & "#"));
      end loop;
      Write_Binary_File (First, Bytes);
      Write_Binary_File (Second, Bytes);

      declare
         A : constant Files.Preview_Decoder.Requester := 101;
         B : constant Files.Preview_Decoder.Requester := 102;
         Asked : Boolean;

         procedure Await (Owner : Files.Preview_Decoder.Requester; Path : String) is
         begin
            Ready := False;
            for Attempt in Files_Suite.Support.Polling (Limit => Seconds (Launch_Limit)) loop
               Files.Preview_Decoder.Take (Owner, Path, Image, Ready, Asked);
               exit when Ready;
            end loop;
         end Await;
      begin
         Files.Preview_Decoder.Take (A, First, Image, Ready, Asked);
         Assert (not Ready and then not Asked, "nothing is asked for before a request");
         Files.Preview_Decoder.Request (A, First, 8);
         Await (A, First);
         Assert (Ready and then Image.Available, "the worker decodes a requested image");
         Assert (Image.Width in 1 .. 8 and then Image.Height in 1 .. 8, "to the size asked for");
         Files.Preview_Decoder.Take (A, First, Image, Ready, Asked);
         Assert (not Ready and then not Asked, "and hands it out once");

         --  Two windows at once: neither cancels the other.
         Files.Preview_Decoder.Request (A, First, 8);
         Files.Preview_Decoder.Request (B, Second, 8);
         Await (A, First);
         Assert (Ready, "the first window still gets its image when a second one asks");
         Await (B, Second);
         Assert (Ready, "and so does the second");

         --  One window moving on before its first is done: that result is
         --  never handed out.
         Files.Preview_Decoder.Request (A, First, 8);
         Files.Preview_Decoder.Request (A, Second, 8);
         Files.Preview_Decoder.Take (A, First, Image, Ready, Asked);
         Assert (not Ready and then not Asked, "the one left behind is no longer asked for");
         for Attempt in Files_Suite.Support.Polling (Limit => Seconds (Launch_Limit)) loop
            Files.Preview_Decoder.Take (A, First, Image, Ready, Asked);
            Assert (not Ready, "the one left behind is never handed out");
            Files.Preview_Decoder.Take (A, Second, Image, Ready, Asked);
            exit when Ready;
         end loop;
         Assert (Ready, "the file now previewed is decoded");

         --  Two windows previewing the same file each get it.
         Files.Preview_Decoder.Request (A, First, 8);
         Files.Preview_Decoder.Request (B, First, 8);
         Await (A, First);
         Assert (Ready and then Image.Available, "one window gets a file another also asks for");
         Await (B, First);
         Assert (Ready and then Image.Available, "and so does the other");

         --  A file that does not decode is reported, and stays reported: the
         --  window does not ask for it again on every poll.
         Write_Binary_File (Join (Root, "broken.jpg"), "not a picture");
         Files.Preview_Decoder.Request (A, Join (Root, "broken.jpg"), 8);
         Await (A, Join (Root, "broken.jpg"));
         Assert (Ready and then not Image.Available, "an undecodable file is reported as such");
         Files.Preview_Decoder.Take (A, Join (Root, "broken.jpg"), Image, Ready, Asked);
         Assert (Asked and then Ready and then not Image.Available,
                 "the failure is still there on the next poll, so nothing asks again");

         --  More windows than slots: the one asked of longest ago gives way.
         for Owner in Files.Preview_Decoder.Requester range 201 .. 209 loop
            Files.Preview_Decoder.Request (Owner, First, 8);
         end loop;
         Await (209, First);
         Assert (Ready, "the newest of many windows gets its preview");
         Files.Preview_Decoder.Take (201, First, Image, Ready, Asked);
         Assert (not Asked, "the oldest of nine windows lost its slot to the ninth");
      end;

      --  Through the model: the preview opens at once, without its image,
      --  and Poll_Quick_Look asks for it and completes it.
      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Root, Files.Settings.Default_Settings);
      begin
         Files.Model.Initialize (Model, Root, Load.Items, Root);
      end;
      Files_Suite.Support.Select_Name (Model, "first.jpg");
      Files.Model.Open_Quick_Look (Model, Files.Operations.Prepare_Quick_Look (Files.Model.Selected_Item (Model)));
      Assert
        (Files.Model.Quick_Look_Content_Of (Model).Kind = Files.Quick_Look.Image_Content,
         "the preview opens as an image");
      Assert
        (Files.Shared_Bytes.Is_Empty (Files.Model.Quick_Look_Content_Of (Model).Image_Pixels),
         "without its decoded image: the decode is not done on the UI thread");
      for Attempt in Files_Suite.Support.Polling (Limit => Seconds (Launch_Limit)) loop
         Files.Operations.Poll_Quick_Look (Model, 103);
         exit when not Files.Shared_Bytes.Is_Empty (Files.Model.Quick_Look_Content_Of (Model).Image_Pixels);
      end loop;
      Assert
        (not Files.Shared_Bytes.Is_Empty (Files.Model.Quick_Look_Content_Of (Model).Image_Pixels),
         "and gets its decoded image from the worker");
   end Test_Quick_Look_Decodes_Off_Thread;
