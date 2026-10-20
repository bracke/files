with Files.Types;

private with Ada.Finalization;
private with System.Atomic_Counters;

--  Immutable, reference-counted byte buffers for decoded thumbnail pixels.
--
--  A directory item, the visible rows built from it and every view snapshot
--  each held their own deep copy of an item's RGBA thumbnail, so each
--  snapshot rebuild (one per scroll step) copied every thumbnail several
--  times. A Bytes value is shared on copy instead: copying it only bumps a
--  count, and the bytes are never modified after To_Shared.
package Files.Shared_Bytes is

   --  A shared, read-only byte buffer; the default value is empty.
   type Bytes is private;

   --  The empty buffer.
   Empty : constant Bytes;

   --  Share a copy of Value.
   --
   --  @param Value Bytes to share.
   --  @return A buffer holding Value; Empty when Value is empty.
   function To_Shared (Value : Files.Types.Byte_Vectors.Vector) return Bytes;

   --  Copy the bytes out, for an API that needs its own vector.
   --
   --  @param Value Buffer to read.
   --  @return A copy of the bytes.
   function To_Vector (Value : Bytes) return Files.Types.Byte_Vectors.Vector;

   --  @param Value Buffer to measure.
   --  @return Number of bytes held.
   function Length (Value : Bytes) return Natural;

   --  @param Value Buffer to test.
   --  @return True when the buffer holds no bytes.
   function Is_Empty (Value : Bytes) return Boolean is (Length (Value) = 0);

   --  Equal when both share one buffer or hold the same bytes.
   --
   --  @param Left First buffer.
   --  @param Right Second buffer.
   --  @return True when the contents are equal.
   overriding function "=" (Left, Right : Bytes) return Boolean;

private

   type Payload is record
      Count : System.Atomic_Counters.Atomic_Counter;
      Data  : Files.Types.Byte_Vectors.Vector;
   end record;

   type Payload_Access is access Payload;

   type Bytes is new Ada.Finalization.Controlled with record
      Ref : Payload_Access := null;
   end record;

   overriding procedure Adjust (Object : in out Bytes);
   overriding procedure Finalize (Object : in out Bytes);

   Empty : constant Bytes := (Ada.Finalization.Controlled with Ref => null);

end Files.Shared_Bytes;
