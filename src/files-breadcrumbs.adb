with Ada.Strings.Unbounded;
with Hostkit.Fs;
with Hostkit.Path_Text;

package body Files.Breadcrumbs is
   use Ada.Strings.Unbounded;

   function Segments
     (Path : String)
      return Segment_Vectors.Vector
   is
      --  Paths are not always spelled with '/'. A Windows path begins with a
      --  drive -- "C:\Users\..." -- or a share -- "\\server\share\..." -- and
      --  is separated by '\', so a splitter that knows only forward slashes
      --  finds no components at all and the breadcrumb bar comes out empty.
      --  On POSIX, however, '\' is an ordinary filename byte and must not
      --  split a real name. Read as Hostkit.Path_Text reads a path, the same
      --  on every host.
      function Is_Separator (Value : Character) return Boolean is
        (Hostkit.Path_Text.Is_Separator_In (Path, Value));

      --  "/", "C:\", "\\server\share": where the path starts.
      Root_Length : constant Natural := Hostkit.Path_Text.Root_Length (Path);

      --  The root without the separators that close it: "C:" or
      --  "\\server\share", which keep their names -- unlike a POSIX root, a
      --  bare separator with nothing to show ("").
      function Root_Name return String is
         Last : Natural := Path'First + Root_Length - 1;
      begin
         while Last >= Path'First and then Is_Separator (Path (Last)) loop
            Last := Last - 1;
         end loop;
         return Path (Path'First .. Last);
      end Root_Name;

      Result   : Segment_Vectors.Vector;
      Ancestor : Unbounded_String := Null_Unbounded_String;
      Index    : Integer := Path'First;

      --  The path's own spelling: Windows accepts both separators, and a
      --  forward-slash path must not turn into a different-looking
      --  breadcrumb target.
      function Separator_Character return Character is
      begin
         for Value of Path loop
            if Is_Separator (Value) then
               return Value;
            end if;
         end loop;
         return Hostkit.Fs.Separator;
      end Separator_Character;

      Separator : constant String := [1 => Separator_Character];
   begin
      if Path = "" then
         return Result;
      end if;

      if Root_Length > 0 then
         declare
            Name : constant String := Root_Name;
         begin
            if Name = "" then
               --  The filesystem root is not shown as its own breadcrumb (a
               --  bare '/' next to the '>' separators reads as a stray mark).
               --  Keep its spelling in Ancestor so click targets remain
               --  absolute.
               Ancestor := To_Unbounded_String (Path (Path'First .. Path'First + Root_Length - 1));
            else
               --  A drive or a share is the first breadcrumb: it is where the
               --  tree starts, and a place the user can click back to.
               Ancestor := To_Unbounded_String (Name & Separator);
               Result.Append (Segment'(Label => To_Unbounded_String (Name), Ancestor_Path => Ancestor));
            end if;
         end;
         Index := Path'First + Root_Length;
      end if;

      while Index <= Path'Last loop
         declare
            Comp_Start : constant Integer := Index;
            Comp_End   : Integer := Index - 1;
         begin
            while Index <= Path'Last
              and then not Is_Separator (Path (Index))
            loop
               Comp_End := Index;
               Index := Index + 1;
            end loop;

            --  Skip the separator that ended this component.
            if Index <= Path'Last then
               Index := Index + 1;
            end if;

            if Comp_End >= Comp_Start then
               declare
                  Name : constant String := Path (Comp_Start .. Comp_End);
               begin
                  if Length (Ancestor) = 0 then
                     Ancestor := To_Unbounded_String (Name);
                  elsif Element (Ancestor, Length (Ancestor)) = Separator (Separator'First) then
                     --  Straight after a root or drive: it already ends in a
                     --  separator. This also preserves the two-byte UNC root.
                     Ancestor := Ancestor & Name;
                  else
                     Ancestor := Ancestor & Separator & Name;
                  end if;

                  Result.Append
                    (Segment'
                       (Label         => To_Unbounded_String (Name),
                        Ancestor_Path => Ancestor));
               end;
            end if;
         end;
      end loop;

      return Result;
   end Segments;

   function Is_Ellipsis
     (Item : Segment)
      return Boolean is
   begin
      return Length (Item.Ancestor_Path) = 0;
   end Is_Ellipsis;

   function Elide
     (Items        : Segment_Vectors.Vector;
      Max_Segments : Positive)
      return Segment_Vectors.Vector
   is
      Result : Segment_Vectors.Vector;
      Count  : constant Natural := Natural (Items.Length);
   begin
      if Count <= Max_Segments then
         return Items;
      end if;

      if Max_Segments < 3 then
         for I in Count - Max_Segments + 1 .. Count loop
            Result.Append (Items.Element (I));
         end loop;
         return Result;
      end if;

      Result.Append (Items.First_Element);
      Result.Append
        (Segment'
           (Label         => To_Unbounded_String (Ellipsis_Label),
            Ancestor_Path => Null_Unbounded_String));

      declare
         Tail : constant Natural := Max_Segments - 2;
      begin
         for I in Count - Tail + 1 .. Count loop
            Result.Append (Items.Element (I));
         end loop;
      end;

      return Result;
   end Elide;

end Files.Breadcrumbs;
