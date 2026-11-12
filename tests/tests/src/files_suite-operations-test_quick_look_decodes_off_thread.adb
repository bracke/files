with Files.Images;
with Files.Preview_Decoder;
with Files.Quick_Look;
separate (Files_Suite.Operations)
   procedure Test_Quick_Look_Decodes_Off_Thread (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Quick_Look.Content_Kind;
      First  : constant String := Join (Root, "first.jpg");
      Second : constant String := Join (Root, "second.jpg");
      Bytes  : constant String := Files_Suite.Support.Red_Jpeg_8x8;
      Image  : Files.Images.Decoded_Image;
      Ready  : Boolean := False;
      Model  : Files.Model.Window_Model;
   begin
      Reset_Root;
      Write_Binary_File (First, Bytes);
      Write_Binary_File (Second, Bytes);

      declare
         A : constant Files.Preview_Decoder.Requester := 101;
         B : constant Files.Preview_Decoder.Requester := 102;
         Asked : Boolean;

         procedure Await (Owner : Files.Preview_Decoder.Requester; Path : String) is
         begin
            Ready := False;
            for Attempt in Files_Suite.Support.Polling loop
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
         for Attempt in Files_Suite.Support.Polling loop
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

         --  However many windows ask, none gives way to another: each gets
         --  its preview, and a window let go of drops its slot.
         for Owner in Files.Preview_Decoder.Requester range 201 .. 209 loop
            Files.Preview_Decoder.Request (Owner, First, 8);
         end loop;
         for Owner in Files.Preview_Decoder.Requester range 201 .. 209 loop
            Await (Owner, First);
            Assert (Ready and then Image.Available, "window" & Owner'Image & " of nine gets its preview");
         end loop;
         Files.Preview_Decoder.Release (201);
         Files.Preview_Decoder.Take (201, First, Image, Ready, Asked);
         Assert (not Asked, "a released window's slot is gone");
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
      for Attempt in Files_Suite.Support.Polling loop
         Files.Operations.Poll_Quick_Look (Model, 103);
         exit when not Files.Shared_Bytes.Is_Empty (Files.Model.Quick_Look_Content_Of (Model).Image_Pixels);
      end loop;
      Assert
        (not Files.Shared_Bytes.Is_Empty (Files.Model.Quick_Look_Content_Of (Model).Image_Pixels),
         "and gets its decoded image from the worker");
   end Test_Quick_Look_Decodes_Off_Thread;
