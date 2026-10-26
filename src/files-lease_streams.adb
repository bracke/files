with Ada.IO_Exceptions;

package body Files.Lease_Streams is
   use type Ada.Streams.Stream_Element_Offset;
   use type Hostkit.Lease_Files.Open_Outcome;

   function Open
     (Path : String;
      Item : in out Input_Stream)
      return Hostkit.Lease_Files.Open_Outcome
   is
      Outcome : Hostkit.Lease_Files.Open_Outcome;
      Length  : Long_Long_Integer;
   begin
      Release (Item);
      Outcome := Hostkit.Lease_Files.Open
        (Path, Hostkit.Lease_Files.Shared, Writable => False,
         Item => Item.Handle);
      if Outcome /= Hostkit.Lease_Files.Opened then
         return Outcome;
      end if;
      Length := Hostkit.Lease_Files.Size (Item.Handle);
      if Length < 0
        or else Length >
          Long_Long_Integer (Ada.Streams.Stream_Element_Offset'Last)
      then
         Release (Item);
         return Hostkit.Lease_Files.Error;
      end if;
      Item.Position := 0;
      Item.Length := Ada.Streams.Stream_Element_Offset (Length);
      Item.Block_Count := 0;
      return Hostkit.Lease_Files.Opened;
   exception
      when others =>
         Release (Item);
         return Hostkit.Lease_Files.Error;
   end Open;

   procedure Release (Item : in out Input_Stream) is
   begin
      Hostkit.Lease_Files.Release (Item.Handle);
      Item.Position := 0;
      Item.Length := 0;
      Item.Block_Count := 0;
   end Release;

   function Size (Item : Input_Stream) return Long_Long_Integer is
     (if Hostkit.Lease_Files.Is_Held (Item.Handle)
      then Long_Long_Integer (Item.Length)
      else -1);

   function End_Of_Stream (Item : Input_Stream) return Boolean is
     (Hostkit.Lease_Files.Is_Held (Item.Handle)
      and then Item.Position = Item.Length);

   overriding procedure Read
     (Stream : in out Input_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      Count : constant Ada.Streams.Stream_Element_Offset :=
        Ada.Streams.Stream_Element_Offset (Item'Length);
   begin
      if Count = 0 then
         Last := Item'First - 1;
      elsif not Hostkit.Lease_Files.Is_Held (Stream.Handle)
        or else Stream.Position > Stream.Length
        or else Count > Stream.Length - Stream.Position
      then
         raise Ada.IO_Exceptions.End_Error;
      elsif Count >= Block_Size then
         --  A large read goes straight to the file.
         if not Hostkit.Lease_Files.Read_At (Stream.Handle, Item, Stream.Position) then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         Stream.Position := Stream.Position + Count;
         Last := Item'Last;
      else
         if Stream.Position < Stream.Block_Start
           or else Stream.Position + Count > Stream.Block_Start + Stream.Block_Count
         then
            --  Refill from Position: as much as the file still holds, at most
            --  a block (the Count bytes asked for are within it).
            declare
               Fill : constant Ada.Streams.Stream_Element_Offset :=
                 Ada.Streams.Stream_Element_Offset'Min (Block_Size, Stream.Length - Stream.Position);
            begin
               if not Hostkit.Lease_Files.Read_At
                 (Stream.Handle, Stream.Block (1 .. Fill), Stream.Position)
               then
                  raise Ada.IO_Exceptions.Data_Error;
               end if;
               Stream.Block_Start := Stream.Position;
               Stream.Block_Count := Fill;
            end;
         end if;
         declare
            From : constant Ada.Streams.Stream_Element_Offset := Stream.Position - Stream.Block_Start + 1;
         begin
            Item := Stream.Block (From .. From + Count - 1);
         end;
         Stream.Position := Stream.Position + Count;
         Last := Item'Last;
      end if;
   end Read;

   overriding procedure Write
     (Stream : in out Input_Stream;
      Item   : Ada.Streams.Stream_Element_Array)
   is
      pragma Unreferenced (Stream, Item);
   begin
      raise Program_Error;
   end Write;

end Files.Lease_Streams;
