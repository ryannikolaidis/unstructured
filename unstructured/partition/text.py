import re
from typing import IO, List, Optional

from unstructured.cleaners.core import clean_bullets
from unstructured.documents.elements import (
    Address,
    Element,
    ElementMetadata,
    ListItem,
    NarrativeText,
    Text,
    Title,
)
from unstructured.nlp.patterns import PARAGRAPH_PATTERN
from unstructured.partition.common import exactly_one
from unstructured.partition.text_type import (
    is_bulleted_text,
    is_possible_narrative_text,
    is_possible_title,
    is_us_city_state_zip,
)


def split_by_paragraph(content: str) -> List[str]:
    return re.split(PARAGRAPH_PATTERN, content)


def partition_text(
    filename: Optional[str] = None,
    file: Optional[IO] = None,
    text: Optional[str] = None,
    encoding: Optional[str] = "utf-8",
    chunk_size: Optional[int] = 4096,
) -> List[Element]:
    """Partitions a text document/file/string into its constituent elements.
    Parameters
    ----------
    filename
        A string defining the target filename path.
    file
        A file-like object using "r" mode --> open(filename, "r").
    text
        The string representation of the .txt document.
    encoding
        The encoding method used to decode the text input. If None, utf-8 will be used.
    """

    # Verify that only one of the arguments was provided
    exactly_one(filename=filename, file=file, text=text)

    elements: List[Element] = []
    metadata = ElementMetadata(filename=filename)

    def process_paragraphs(paragraphs: List[str]) -> None:
        nonlocal elements, metadata

        if isinstance(paragraphs, str):
            # protect against a string input where each character
            # would be processed in the loop below
            paragraphs = [ctext]
        
        for ctext in paragraphs:
            ctext = ctext.strip()

            if ctext == "":
                continue
            if is_bulleted_text(ctext):
                elements.append(ListItem(text=clean_bullets(ctext), metadata=metadata))
            elif is_us_city_state_zip(ctext):
                elements.append(Address(text=ctext, metadata=metadata))
            elif is_possible_narrative_text(ctext):
                elements.append(NarrativeText(text=ctext, metadata=metadata))
            elif is_possible_title(ctext):
                elements.append(Title(text=ctext, metadata=metadata))
            else:
                elements.append(Text(text=ctext, metadata=metadata))

    def process_file(file_object):
        nonlocal chunk

        while True:
            read_block = file_object.read(chunk_size)
            chunk = chunk + read_block
            
            paragraphs = split_by_paragraph(chunk)
            # the last paragraph may be incomplete, so process everything except that
            if read_block == "":
                # end of the file, just process what you got
                process_paragraphs(paragraphs)
                break
            elif len(paragraphs) > 1:
                process_paragraphs(paragraphs[:-1])
                chunk = paragraphs[-1]

    chunk = ""
    if filename is not None:
        with open(filename, encoding=encoding) as f:
            process_file(f)

    elif file is not None:
        process_file(file)

    elif text is not None:
        file_text = process_paragraphs(split_by_paragraph(text))

    return elements
