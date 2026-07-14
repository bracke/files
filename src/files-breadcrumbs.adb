with Ada.Strings.Unbounded;

package body Files.Breadcrumbs is
   use Ada.Strings.Unbounded;

   function Segments
     (Path : String)
      return Segment_Vectors.Vector
   is
      --  Paths are not always spelled with '/'. A Windows path begins with a
      --  drive -- "C:\Users\..." -- and is separated by '\', so a splitter that
      --  knows only forward slashes finds no components at all and the breadcrumb
      --  bar comes out empty.
      function Is_Separator (Value : Character) return Boolean is
        (Value = '/' or else Value = '\');

      function Drive_Prefix return Natural is
      begin
         --  "C:\" or "C:/": the root is the drive, and it keeps its name --
         --  unlike a POSIX root, which is a bare separator with nothing to show.
         if Path'Length >= 3
           and then Path (Path'First + 1) = ':'
           and then Is_Separator (Path (Path'First + 2))
         then
            return 3;
         end if;

         return 0;
      end Drive_Prefix;

      Result   : Segment_Vectors.Vector;
      Ancestor : Unbounded_String := Null_Unbounded_String;
      Drive    : constant Natural := Drive_Prefix;
      Index    : Integer := Path'First;

      Absolute : constant Boolean :=
        Drive > 0
        or else (Path'Length > 0 and then Is_Separator (Path (Path'First)));

      Separator : constant String :=
        (if Drive > 0 then "\" else "/");
   begin
      if Path = "" then
         return Result;
      end if;

      if Drive > 0 then
         --  The drive itself is the first breadcrumb: "C:" is where the tree
         --  starts, and it is a place the user can click back to.
         declare
            Root : constant String := Path (Path'First .. Path'First + 1);
         begin
            Ancestor := To_Unbounded_String (Root & Separator);
            Result.Append
              (Segment'
                 (Label         => To_Unbounded_String (Root),
                  Ancestor_Path => Ancestor));
         end;
         Index := Path'First + Drive;

      elsif Absolute then
         --  The filesystem root is not shown as its own breadcrumb (a bare '/'
         --  next to the '>' separators reads as a stray mark); skip the leading
         --  slash and start at the first named component.
         Index := Path'First + 1;
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
                     Ancestor :=
                       (if Absolute
                        then To_Unbounded_String (Separator & Name)
                        else To_Unbounded_String (Name));
                  elsif Drive > 0 and then Natural (Result.Length) = 1 then
                     --  Straight after the drive: "C:\" already ends in one.
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
