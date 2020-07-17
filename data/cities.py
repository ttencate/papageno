'''
ORM classes for storing cities.
'''

from sqlalchemy import Column, Integer, Float, String, Boolean, DateTime, Date, Enum, JSON, ForeignKey
from sqlalchemy.orm import relationship

from base import Base


class City(Base):
    '''
    A single city.
    '''
    __tablename__ = 'cities'

    city_id = Column(Integer, primary_key=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    lat = Column(Float, nullable=False)
    lon = Column(Float, nullable=False)
    population = Column(Integer)
