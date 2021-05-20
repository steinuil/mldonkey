# Tree Hash EXchange format (THEX)

## Abstract

This memo presents the Tree Hash Exchange (THEX) format, for exchanging Merkle Hash Trees built up from the subrange hashes of discrete digital files. Such tree hash data structures assist in file integrity verification, allowing arbitrary subranges of bytes to be verified before the entire file has been received. 

## Introduction

The Merkle Hash Tree, invented by Ralph Merkle, is a hash construct that exhibits desirable properties for verifying the integrity of files and file subranges in an incremental or out-of-order fashion. This document describes a binary serialization format for hash trees that is compact and optimized for both sequential and random access. This memo has two goals:

1. To describe Merkle Hash Trees and how they are used for file integrity verification.
2. To describe a serialization format for storage and transmission of hash trees.

## Merkle Hash Trees

It is common practice in distributed systems to use secure hash algorithms to verify the integrity of content. The employment of secure hash algorithms enables systems to retreive content from completely untrusted hosts with only a small amount of trusted metadata.

Typically, algorithms such as SHA-1 and MD5 have been used to check the content integrity after retrieving the entire file. These full file hash techniques work fine in an environment where the content is received from a single host and there are no streaming requirements. However, there are an increasing number of systems that retrieve a single piece of content from multiple untrusted hosts, and require content verification well in advance of retrieving the entire file.

Many modern peer-to-peer content delivery systems employ fixed size "block hashes" to provide a finer level of granularity in their integrity checking. This approach is still limited in the verification resolution it can attain. Additionally, all of the hash information must be retrieved from a trusted host, which can limit the scalability and reliability of the system.

Another way to verify content is to use the hash tree approach. This approach has the desired characteristics missing from the full file hash approach and works well for very large files. The idea is to break the file up into a number of small pieces, hash those pieces, and then iteratively combine and rehash the resulting hashes in a tree-like fashion until a single "root hash" is created.

The root hash by itself behaves exactly the same way that full file hashes do. If the root hash is retrieved from a trusted source, it can be used to verify the integrity of the entire content. More importantly, the root hash can be combined with a small number of other hashes to verify the integrity of any of the file segments.

For example, consider a file made up of four segments, S1, S2, S3, and S4. Let H() be the hash function, and '+' indicate concatenation. You could take the traditional hash value:

```
VALUE=H(S1+S2+S3+S4)
```

Or, you could employ a tree approach. The tree hash utilizes two hash algorithms - one for leaf hashes and one for internal hashes. Let LH() be the leaf hash function and IH() be the internal hash function:

```
             ROOT=IH(E+F)
              /      \
             /        \
      E=IH(A+B)       F=IH(C+D)
      /     \           /    \
     /       \         /      \
A=LH(S1)  B=LH(S2) C=LH(S3)  D=LH(S4)
```

Now, assuming that the ROOT is retrieved from a trusted source, the integrity of a file segment coming from an untrusted source can be checked with a small amount of hash data. For instance, if S1 is received from an untrusted host, the integrity of S1 can be verified with just B and F. With these, it can be verified that, yes: S1 can be combined up to equal the ROOT hash, even without seeing the other segments. (It is just as impractical to create falsified values of B and F as it is to manipulate any good hash function to give desired results -- so B and F can come from untrusted sources as well.) Similarly, if some other untrusted source provides segments S3 and S4, their integrity can be easily checked when combined with hash E. From segments S3 and S4, the values of C and D and then F can be calculated. With these, you can verify that S3 and S4 can combine up to create the ROOT -- even if other sources are providing bogus S1 and S2 segments. Bad info can be immediately recognized and discarded, and good info retained, even in situations where you could not even begin to calculate a traditional full-file hash.

Another interesting property of the tree approach is that it can be used to verify (tree-aligned) subranges whose size is any multiple of the base segment size.

Consider for example an initial segment size of 1,024 bytes, and a file of 32GB. You could verify a single 1,024-byte block, with about 25 proof-assist values, or a block of size 16GB, with a single proof-assist value -- or anything in between.

### Hash Functions

The strength of the hash tree construct is only as strong as the underlying hash algorithm. Thus, it is RECOMMENDED that a secure hash algorithm such as SHA-1 be used as the basis of the hash tree.

In order to protect against collisions between leaf hashes and internal hashes, different hash constructs are used to hash the leaf nodes and the internal nodes. The same hash algorithm is used as the basis of each construct, but a single '1' byte in network byte order, or 0x01 is prepended to the input of the internal node hashes, and a single '0' byte, or 0x00 is prepended to the input of the leaf node hashes.

Let H() be the secure hash algorithm, for example SHA-1.

```
internal hash function = IH(X) = H(0x01, X)

leaf hash function = LH(X) = H(0x00, X)
```

### Unbalanced Trees

For trees that are unbalanced -- that is, they have a number of leaves which is not a power of 2 -- interim hash values which do not have a sibling value to which they may be concatenated are promoted, unchanged, up the tree until a sibling is found.

For example, consider a file made up of 5 segments, S1, S2, S3, S4, and S5.

```
                     ROOT=IH(H+E)
                      /        \
                     /          \
              H=IH(F+G)          E
              /       \           \
             /         \           \
      F=IH(A+B)       G=IH(C+D)     E
      /     \           /     \      \
     /       \         /       \      \
A=LH(S1)  B=LH(S2) C=LH(S3)  D=LH(S4) E=LH(S5)
```

In the above example, E does not have any immediate siblings with which to be combined to calculate the next generation. So, E is promoted up the tree, without being rehashed, until it can be paired with value H. The values H and E are then concatenated, and hashed, to produce the ROOT hash.

### Choice Of Segment Size

Any segment size is possible, but the choice of base segment size establishes the smallest possible unit of verification.

If the the segment size is equal to or larger than the file to be hashed, the tree hash value is the value of the single segment's value, which is the same as the underlying hash algorithm value for the whole file.

A segment size equal to the digest algorithm output size would more than double the total amount of data to be hashed, and thus more than double the time required to calculate the tree hash structure, as compared to a simple full-file hash. However, once the segment size reaches several multiples of the digest size, calculating the tree adds only a small fractional time overhead beyond what a traditional full-file hash would cost.

Otherwise, smaller segments are better. Smaller segments allow, but do not require, the retention and use of fine-grained verification info, (A stack-based tree calculation procedure need never retain more than one pending internal node value per generation before it can be combined with a sibling, and all interim values below a certain generation size of interest can be discarded.) Further, it is beneficial for multiple application domains and even files of wildly different sizes to share the same base segment size, so that tree structures can be shared and used to discover correlated subranges.

Thus the authors recommend a segment size of 1,024 bytes for most applications, as a sort of "smallest common denominator", even for applications involving multi-gigabyte or terabyte files. This segment size is 40-50 times larger than common secure hash digest lengths (20-24 bytes), and thus adds no more than 5-10% in running time as compared to the "infinite segment" size case -- the traditional full-file hash.

Considering a 1 terabyte file, the maximum dynamic state required during the calculation of the tree root value is 29 interim node values -- less than 1KB assuming a 20-byte digest algorithm like SHA-1. Only interim values in generations of interest for range verification need to be remembered for tree exchange, so if only 8GB ranges ever need to be verified, all but the top 8 generations of internal values (255 hashes) can be discarded.

## Serialization Format

This section presents a serialization format for Merkle Hash Trees that utilizes the Direct Internet Message Encapsulation (DIME) format. DIME is a generic message format that allows for multiple payloads, either text or binary. The Merkle Hash Tree serialization format consists of two different payloads. The first is XML encoded meta-data about the hash tree, and the second is binary serialization of the tree itself. The binary serialization is required for two important reasons:

1. Compactness of Representation - A key virtue of the hash tree approach is that it provides considerable integrity checking power with a relatively small amount of data. A typical hash tree consists of a large number of small hashes. Thus a text encoding, such as XML, could easily double the storage and transmission requirements of the hash tree, negating one of its key benefits.
2. Random Access - In order to take full advantage of the hash tree construct, it is often necessary to read the elements of the hash tree in a random access fashion. A common usage of this serialization format will be to access hash data over the HTTP protocol using "Range Requests". This will allow implementors to retrieve small bits of hash information on-demand, even requesting different parts of the tree from different hosts on the network.

### DIME Encapsulation

It is RECOMMENDED that DIME be used to encapsulate the payloads described in this specification. The current version of DIME is "draft-nielsen-dime-01" at (http://gotdotnet.com/team/xml_wsspecs/dime/default.aspx).

It is RECOMMENDED that the first payload in the DIME Message be the XML Tree Description. The XML Tree description payload MUST be before the the binary serialized tree.

It is RECOMMENDED that the binary serialized tree be stored in a single payload rather than using chunked payloads. This will allow implementations to read the tree hash data in a random access fashion within the payload.

### XML Tree Description

The XML Tree Description contains metadata about the hash tree and file that is necessary to interpret the binary serialized tree. An important consideration in the design of THEX is the intention for it to be received from untrusted sources within a distributed network. The only information that needs to be obtained from a trusted source is the root hash and the segment size. The root hash by itself can be used to verify the integrity of the serialized tree and of the file itself.

It is RECOMMENDED that implementers assume that the serialized file was obtained from an untrusted source, thus the use of this format to store non-verifiable information, such as general file metadata, is highly discouraged. For instance, a malicious party could easily forge metadata, such as the author or file name.

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE hashtree system "http://open-content.net/spec/thex/thex.dtd">
<hashtree>
    <file size='1146045066' segmentsize='1024'/>
    <digest algorithm='http://www.w3.org/2000/09/xmldsig#sha1' 
            outputsize='20'/>
    <serializedtree depth='22' 
                    type='http://open-content.net/spec/thex/breadthfirst' 
                    uri='uuid:09233523-345b-4351-b623-5dsf35sgs5d6'/>
</hashtree>
```

#### File Size

The file size attribute refers to the size, in bytes, of the file that the hash tree was generated from.

#### File Segment Size

The file segment size identifies the size, in bytes, of the file segments that were used to create the hash tree. As noted in Choice Of Segment Size, it is recommended that applications use a small, common segment size such as 1,024 bytes in order to retain maximum flexibility and interoperability.

#### Digest Algorithm

This attribute provides the identifier URI for the digest algorithm. A URI is used here as an identifier instead of a regular string to avoid the overhead of IANA-style registration. By using URIs, new types can be created without having to consult any other entity. The URIs are only to be used for type identification purposes, but it is RECOMMENDED that the URIs point to information about the given digest function. This convention is inspired by RFC 3275, the XML Signature Specification. For instance, the SHA-1 algorithm is identified by `http://www.w3.org/2000/09/xmldsig#sha1`. All digest algorithms defined in RFC 3275 are supported. The Tiger algorithm is also supported and is identified by "http://open-content.net/spec/digest/tiger".

#### Digest Output Size

This attribute specifies the size of the output of the hash function, in bytes.

#### Serialized Tree Depth

This attribute specifies the number of levels of the tree that have been serialized. This value allows control over the amount of storage space required by the serialized tree. In general, each row added to the tree will double the storage requirements while also doubling the verification resolution.

#### Serialized Tree Type

This attribute provides the identifier URI for the serialization type. Just as with the Digest Algorithm, new serialization types can be added and described without going through a formal IANA-style process. One serialization type is defined for "Breadth-First Serialization" later in this document.

#### Serialized Tree URI

This attribute provides the URI of the binary serialized tree payload. If used within a DIME payload, it is recommended that this URI be location independant, such as the "uuid:" URI's used in the SOAP in DIME specification or SHA-1 URNs.

### Breadth-First Serialization

Normal breadth-first serialization is the recommended manner in which to serialize the hash tree. This format includes the root hash first, and then each "row" of hashes is serialized until the tree has been serialized to the lowest level as specified by the "Serialized Tree Depth" field.

For example, consider a file made up of 5 segments, S1, S2, S3, S4, and S5.

```
                     ROOT=IH(H+E)
                      /        \
                     /          \
              H=IH(F+G)          E
              /       \           \
             /         \           \
      F=IH(A+B)       G=IH(C+D)     E
      /     \           /     \      \
     /       \         /       \      \
A=LH(S1)  B=LH(S2) C=LH(S3)  D=LH(S4) E=LH(S5)
```

The hashes would be serialized in the following order: ROOT, H, E, F, G, E, A, B, C, D, E. Notice that E is serialized as a part of the each row. This is due to its promotion as there are no available siblings in the lower rows. If we choose to serialize the entire tree, the serialized tree depth would be 4, and for a 20 byte digest output, the entire tree payload would occupy 11*20 = 220 bytes.

#### Serialization Type URI

The serialization type URI for a Merkle Hash Tree serialized in normal breadth-first form is `http://open-content.net/spec/thex/breadthfirst`.

## Authors' Addresses


```
       Justin Chapweske
       Onion Networks, Inc.
       1668 Rosehill Circle
       Lauderdale, MN 55108
       US

EMail: justin@onionnetworks.com
  URI: http://onionnetworks.com/


       Gordon Mohr
       Bitzi, Inc.

EMail: gojomo@bitzi.com
  URI: http://bitzi.com/
```

## Appendix A. Test Vectors

The following are test vectors for producing THEX hash trees using the Tiger hash algorithm. The 'urn:sha1' entries specify the full file SHA-1 of the data, while the 'urn:tree:tiger' entries specify the root of the THEX hash tree of the data.

The empty (zero-length) file:

```
urn:sha1:3I42H3S6NNFQ2MSVX7XZKYAYSCX5QBYJ
urn:tree:tiger:LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ
```
  
A file with a single zero byte:

```
urn:sha1:LOUTZHNQZ74T6UVVEHLUEDSD63W2E6CP
urn:tree:tiger:VK54ZIEEVTWNAUI5D5RDFIL37LX2IQNSTAXFKSA
```

A file with 1024 'A' characters:

```
urn:sha1:ORWD6TJINRJR4BS6RL3W4CWAQ2EDDRVU
urn:tree:tiger:L66Q4YVNAFWVS23X2HJIRA5ZJ7WXR3F26RSASFA
```
  
A file with 1025 'A' characters:

```
urn:sha1:UUHHSQPHQXN5X6EMYK6CD7IJ7BHZTE77
urn:tree:tiger:PZMRYHGY6LTBEH63ZWAHDORHSYTLO4LEFUIKHWY
```
