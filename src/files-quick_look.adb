with Ada.Strings.Unbounded;

package body Files.Quick_Look is
   use Ada.Strings.Unbounded;

   function Looks_Binary
     (Raw_Bytes : String)
      return Boolean
   is
      Control_Count : Natural := 0;
   begin
      if Raw_Bytes'Length = 0 then
         return False;
      end if;

      for Char of Raw_Bytes loop
         declare
            Code : constant Natural := Character'Pos (Char);
         begin
            if Code = 0 then
               --  A NUL byte is a decisive signal of non-text content.
               return True;
            elsif Code < 32
              and then Char /= ASCII.HT
              and then Char /= ASCII.LF
              and then Char /= ASCII.CR
              and then Char /= ASCII.FF
            then
               Control_Count := Control_Count + 1;
            end if;
         end;
      end loop;

      --  Treat a large share of stray control bytes as binary; ordinary text
      --  and source files stay well under this threshold.
      return Control_Count * 100 > Raw_Bytes'Length * 10;
   end Looks_Binary;

   --  Split Raw_Bytes into at most Max_Preview_Lines lines on LF boundaries,
   --  stripping a trailing CR from each line. Truncated is set when the input
   --  holds more lines than the cap.
   procedure Split_Lines
     (Raw_Bytes : String;
      Lines     : out Files.Types.String_Vectors.Vector;
      Truncated : out Boolean)
   is
      Current : Unbounded_String;
      Started : Boolean := False;

      procedure Flush is
         Raw  : constant String := To_String (Current);
         Last : Natural := Raw'Last;
      begin
         if Raw'Length > 0 and then Raw (Raw'Last) = ASCII.CR then
            Last := Raw'Last - 1;
         end if;
         Lines.Append (To_Unbounded_String (Raw (Raw'First .. Last)));
         Current := Null_Unbounded_String;
      end Flush;
   begin
      Lines.Clear;
      Truncated := False;

      for Char of Raw_Bytes loop
         Started := True;
         if Char = ASCII.LF then
            if Natural (Lines.Length) >= Max_Preview_Lines then
               Truncated := True;
               return;
            end if;
            Flush;
         else
            Append (Current, Char);
         end if;
      end loop;

      --  Emit any trailing partial line (a file that does not end in LF).
      if Started and then Length (Current) > 0 then
         if Natural (Lines.Length) >= Max_Preview_Lines then
            Truncated := True;
         else
            Flush;
         end if;
      end if;
   end Split_Lines;

   function Prepare_Content
     (Name           : String;
      Filetype       : String;
      Icon_Id        : String;
      Kind           : Files.Types.Item_Kind;
      Size_Available : Boolean;
      Size           : Long_Long_Integer;
      Is_Image       : Boolean;
      Image_Path     : String;
      Raw_Bytes      : String)
      return Quick_Look_Content
   is
      use type Files.Types.Item_Kind;

      Content : Quick_Look_Content;
   begin
      Content.Name           := To_Unbounded_String (Name);
      Content.Filetype       := To_Unbounded_String (Filetype);
      Content.Icon_Id        := To_Unbounded_String (Icon_Id);
      Content.Size_Available := Size_Available;
      Content.Size           := Size;
      Content.Image_Path     := To_Unbounded_String (Image_Path);

      if Is_Image then
         Content.Kind := Image_Content;
         return Content;
      end if;

      --  Only ordinary and executable regular files are candidates for text
      --  preview; directories, symlinks, and unknown entries fall back to the
      --  info card, as do empty or binary reads.
      if (Kind = Files.Types.Regular_File_Item
          or else Kind = Files.Types.Executable_Item)
        and then Raw_Bytes'Length > 0
        and then not Looks_Binary (Raw_Bytes)
      then
         Content.Kind := Text_Content;
         Split_Lines (Raw_Bytes, Content.Text_Lines, Content.Text_Truncated);
      else
         Content.Kind := Info_Content;
      end if;

      return Content;
   end Prepare_Content;

end Files.Quick_Look;
