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
      --  Equivalent to Control_Count * 10 > Length, without overflowing for a
      --  very large caller-supplied buffer.
      return Control_Count > Raw_Bytes'Length / 10;
   end Looks_Binary;

   --  Raw cut back to its last whole UTF-8 character: a multibyte sequence
   --  the read cut short is dropped. Anything else is left as it is.
   function Trim_To_Character (Raw : String) return String is
      Lead : Natural := Raw'Last;
   begin
      --  Step back over at most three continuation bytes (10xxxxxx).
      while Lead >= Raw'First
        and then Raw'Last - Lead < 3
        and then Character'Pos (Raw (Lead)) in 16#80# .. 16#BF#
      loop
         Lead := Lead - 1;
      end loop;
      if Lead < Raw'First then
         return Raw;
      end if;
      declare
         Code   : constant Natural := Character'Pos (Raw (Lead));
         Needed : constant Natural :=
           (if Code in 16#C0# .. 16#DF# then 2
            elsif Code in 16#E0# .. 16#EF# then 3
            elsif Code in 16#F0# .. 16#F7# then 4
            else 1);
      begin
         if Raw'Last - Lead + 1 < Needed then
            return Raw (Raw'First .. Lead - 1);
         end if;
         return Raw;
      end;
   end Trim_To_Character;

   --  Split Raw_Bytes into at most Max_Preview_Lines lines on LF boundaries,
   --  stripping a trailing CR from each line. Truncated is set when the input
   --  holds more lines than the cap, or when Complete is False: the bytes are
   --  then a prefix of the file, so their last line was cut off -- it is
   --  dropped, or, when it is the only line, cut back to a whole character.
   procedure Split_Lines
     (Raw_Bytes : String;
      Complete  : Boolean;
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
      Truncated := not Complete;

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
         elsif Complete then
            Flush;
         elsif Lines.Is_Empty then
            Current := To_Unbounded_String (Trim_To_Character (To_String (Current)));
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
      Raw_Bytes      : String;
      Bytes_Complete : Boolean := True)
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
         Split_Lines (Raw_Bytes, Bytes_Complete, Content.Text_Lines, Content.Text_Truncated);
      else
         Content.Kind := Info_Content;
      end if;

      return Content;
   end Prepare_Content;

end Files.Quick_Look;
