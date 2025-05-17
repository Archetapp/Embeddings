# OpenAI Embeddings App

A simple macOS application for extracting text from files, generating OpenAI embeddings, and performing semantic search.

## Features

- Import various file types (PDF, text, RTF, HTML, etc.)
- Extract raw text content from files
- Generate OpenAI embeddings for imported documents
- Perform semantic search using a search bar
- Results are sorted based on embedding similarity

## Requirements

- macOS 13.0 or later
- An OpenAI API key (for embedding generation)

## Usage

1. Launch the application
2. Enter your OpenAI API key when prompted (or click the key icon to set it)
3. Click the "+" icon to import one or more files
4. Click "Generate Embeddings" to create embeddings for all documents
5. Use the search bar to find semantically similar content

## Supported File Types

- Plain Text (.txt)
- PDF
- RTF (Rich Text Format)
- HTML
- XML
- Property Lists
- JSON
- YAML
- Markdown
- CSV

## Implementation Details

The app uses:
- SwiftUI for the user interface
- OpenAI's text-embedding-3-small model for embeddings
- Cosine similarity for ranking search results
- PDFKit for PDF text extraction

## Privacy

Your documents are processed locally. Only the text content is sent to OpenAI's API for embedding generation. No data is stored on external servers.

## License

MIT License 